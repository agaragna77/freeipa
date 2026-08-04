# Copyright (C) 2026  FreeIPA Contributors see COPYING for license

"""
KeyConstraint / basic profile tests aligned with Dogtag PKI behavior.

Dogtag references:
- KeyConstraint.java (legacy keyType/keyParameters + allowedKeys.* upgrade)
- KeyConstraintTest (algorithm / allowedKeys config)
- CA profile workflows (caServerCert, AdminCert, caDirUserCert, …) that
  reject CSRs whose key type/size is outside the profile constraint

Existing ipacta/tests/test_profiles.py covers .cfg parsing. This module
covers key-constraint validation itself — the piece needed for an
IPACTA KeyConstraint upgrade matching Dogtag KeyConstraintRefactoring.
"""

from pathlib import Path

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, rsa

from ipacta.profile.constraints import KeyConstraint, create_constraint
from ipacta.profile.parser import ProfileParser

REPO_PROFILES = (
    Path(__file__).resolve().parents[2] / "install" / "share" / "profiles"
)


class _FakeCSR:
    """Minimal CSR stand-in: KeyConstraint only needs public_key()."""

    def __init__(self, public_key):
        self._public_key = public_key

    def public_key(self):
        return self._public_key


def _make_rsa_csr(key_size=2048, cn="server.example.com", realm="IPA.TEST"):
    key = rsa.generate_private_key(public_exponent=65537, key_size=key_size)
    subject = x509.Name(
        [
            x509.NameAttribute(x509.oid.NameOID.ORGANIZATION_NAME, realm),
            x509.NameAttribute(x509.oid.NameOID.COMMON_NAME, cn),
        ]
    )
    csr = (
        x509.CertificateSigningRequestBuilder()
        .subject_name(subject)
        .sign(key, hashes.SHA256())
    )
    return csr, key


def _make_ec_csr(curve=ec.SECP256R1()):
    """Build a CSR-like object with an EC public key (no OpenSSL sign)."""
    key = ec.generate_private_key(curve)
    return _FakeCSR(key.public_key()), key


@pytest.fixture
def ipacta_config():
    """Minimal global config so KeyConstraint can read CA defaults."""
    import configparser
    import ipacta

    cfg = configparser.RawConfigParser()
    cfg.add_section("global")
    cfg.set("global", "realm", "IPA.TEST")
    cfg.set("global", "domain", "ipa.test")
    cfg.set("global", "basedn", "dc=ipa,dc=test")
    cfg.add_section("ca")
    cfg.set("ca", "min_rsa_key_size", "2048")
    cfg.set("ca", "max_rsa_key_size", "8192")
    cfg.set("ca", "allowed_rsa_exponents", "65537")
    ipacta.set_global_config(cfg)
    return cfg


# ---------------------------------------------------------------------------
# Legacy keyType / keyParameters (Dogtag AdminCert / caDirUserCert style)
# ---------------------------------------------------------------------------


class TestLegacyKeyConstraint:
    """Mirrors Dogtag profiles that still use keyType + keyParameters."""

    def test_rsa_allowed_size_accepted(self, ipacta_config):
        # AdminCert.cfg historically: keyType=RSA, keyParameters=1024,2048,3072,4096
        constraint = KeyConstraint(
            keyType="RSA", keyParameters="1024,2048,3072,4096"
        )
        csr, _ = _make_rsa_csr(2048)
        assert constraint.validate(csr, {}) == []

    def test_rsa_disallowed_size_rejected(self, ipacta_config):
        # caDirUserCert / ACME-style: only 2048+
        constraint = KeyConstraint(
            keyType="RSA", keyParameters="2048,3072,4096"
        )
        csr, _ = _make_rsa_csr(1024)
        errors = constraint.validate(csr, {})
        assert errors
        assert any("1024" in e for e in errors)

    def test_rsa_wrong_type_rejected(self, ipacta_config):
        constraint = KeyConstraint(
            keyType="RSA", keyParameters="2048,3072,4096"
        )
        csr, _ = _make_ec_csr()
        errors = constraint.validate(csr, {})
        assert errors
        assert any("RSA" in e for e in errors)

    def test_ec_allowed_curve_accepted(self, ipacta_config):
        # ECAdminCert style lists nistp*; cryptography uses secp256r1
        csr, _ = _make_ec_csr(ec.SECP256R1())
        constraint = KeyConstraint(
            keyType="EC", keyParameters=csr.public_key().curve.name
        )
        assert constraint.validate(csr, {}) == []

    def test_ec_disallowed_curve_rejected(self, ipacta_config):
        constraint = KeyConstraint(keyType="EC", keyParameters="secp384r1")
        csr, _ = _make_ec_csr(ec.SECP256R1())
        errors = constraint.validate(csr, {})
        assert errors

    def test_factory_creates_key_constraint(self, ipacta_config):
        constraint = create_constraint(
            "keyConstraintImpl",
            {"keyType": "RSA", "keyParameters": "2048,3072,4096"},
        )
        assert isinstance(constraint, KeyConstraint)
        csr, _ = _make_rsa_csr(2048)
        assert constraint.validate(csr, {}) == []

    def test_no_key_parameters_uses_global_min_max(self, ipacta_config):
        """When keyParameters is empty, Dogtag/IPACTA use global RSA limits."""
        constraint = KeyConstraint(keyType="RSA", keyParameters=None)
        csr_ok, _ = _make_rsa_csr(2048)
        assert constraint.validate(csr_ok, {}) == []

        csr_small, _ = _make_rsa_csr(1024)
        errors = constraint.validate(csr_small, {})
        assert errors
        assert any("1024" in e for e in errors)


# ---------------------------------------------------------------------------
# IPA shipped profiles (source templates under install/share/profiles)
# ---------------------------------------------------------------------------


def _load_profile(name, context=None):
    path = REPO_PROFILES / f"{name}.cfg"
    if not path.exists():
        pytest.skip(f"Profile template missing: {path}")
    context = context or {
        "DOMAIN": "ipa.test",
        "IPA_CA_RECORD": "ipa-ca.ipa.test",
        "SUBJECT_DN_O": "IPA.TEST",
        "CRL_ISSUER": "CN=Certificate Authority,O=IPA.TEST",
        "REALM": "IPA.TEST",
    }
    return ProfileParser(str(path)).parse(context)


def _key_constraint_from_profile(profile):
    for policy in profile.policies:
        if isinstance(policy.constraint, KeyConstraint):
            return policy.constraint
    pytest.fail(f"No KeyConstraint in profile {profile.profile_id}")


def _assert_allowed_keys_loaded(constraint, profile_id):
    """Fail until KeyConstraint parses Dogtag allowedKeys.* from the profile."""
    assert getattr(constraint, "allowed_keys", None) or any(
        "allowed" in n.lower() for n in vars(constraint)
    ), (
        f"{profile_id}: KeyConstraint did not load allowedKeys.* "
        "(upgrade KeyConstraint to Dogtag allowedKeys syntax)"
    )


class TestShippedProfileKeyConstraints:
    """Basic profile key checks using FreeIPA shipped .cfg templates."""

    def test_profiles_use_allowed_keys_not_legacy(self, ipacta_config):
        """Shipped templates must use Dogtag allowedKeys syntax."""
        for name in (
            "caIPAserviceCert",
            "caIPAserviceCert.UPGRADE",
            "IECUserRoles",
            "KDCs_PKINIT_Certs",
            "acmeIPAServerCert",
        ):
            profile = _load_profile(name)
            raw = profile.raw_config
            allowed = [
                k for k in raw if ".constraint.params.allowedKeys." in k
            ]
            assert allowed, f"{name}: missing allowedKeys.* params"
            assert not any(
                k.endswith(".constraint.params.keyType")
                or k.endswith(".constraint.params.keyParameters")
                for k in raw
            ), f"{name}: legacy keyType/keyParameters must be removed"

    def test_caIPAserviceCert_allows_rsa_ec_mldsa(self, ipacta_config):
        profile = _load_profile("caIPAserviceCert")
        raw = profile.raw_config
        for key in (
            "allowedKeys.RSA.2048",
            "allowedKeys.EC.nistp256",
            "allowedKeys.MLDSA.65",
        ):
            assert any(key in k and raw[k] == "true" for k in raw), key

    def test_KDCs_PKINIT_rsa_only_no_1024(self, ipacta_config):
        profile = _load_profile("KDCs_PKINIT_Certs")
        raw = profile.raw_config
        assert any("allowedKeys.RSA.2048" in k for k in raw)
        assert not any("allowedKeys.RSA.1024" in k for k in raw)
        assert not any("allowedKeys.EC." in k for k in raw)

        constraint = _key_constraint_from_profile(profile)
        _assert_allowed_keys_loaded(constraint, "KDCs_PKINIT_Certs")
        csr_bad, _ = _make_rsa_csr(1024)
        csr_ok, _ = _make_rsa_csr(2048)
        assert constraint.validate(csr_bad, {}), (
            "1024 must be rejected for KDCs_PKINIT_Certs"
        )
        assert constraint.validate(csr_ok, {}) == []

    def test_acmeIPAServerCert_allows_rsa_and_ec(self, ipacta_config):
        profile = _load_profile("acmeIPAServerCert")
        raw = profile.raw_config
        assert any("allowedKeys.RSA.2048" in k for k in raw)
        assert any("allowedKeys.EC.nistp256" in k for k in raw)
        assert not any("allowedKeys.RSA.1024" in k for k in raw)
        _assert_allowed_keys_loaded(
            _key_constraint_from_profile(profile), "acmeIPAServerCert"
        )

    def test_IECUserRoles_accepts_rsa_2048(self, ipacta_config):
        profile = _load_profile("IECUserRoles")
        constraint = _key_constraint_from_profile(profile)
        _assert_allowed_keys_loaded(constraint, "IECUserRoles")
        csr, _ = _make_rsa_csr(2048)
        assert constraint.validate(csr, {}) == []

    def test_caIPAserviceCert_accepts_rsa_2048(self, ipacta_config):
        profile = _load_profile("caIPAserviceCert")
        constraint = _key_constraint_from_profile(profile)
        _assert_allowed_keys_loaded(constraint, "caIPAserviceCert")
        csr, _ = _make_rsa_csr(2048)
        assert constraint.validate(csr, {}) == []

# ---------------------------------------------------------------------------
# Inline .cfg snippets (Dogtag caServerCert / AdminCert style)
# ---------------------------------------------------------------------------


ADMIN_CERT_KEY_POLICY = """\
profileId=testAdminCert
classId=caEnrollImpl
name=Test Admin Cert
desc=Minimal profile for KeyConstraint tests
enable=true
visible=false
auth.instance_id=raCertAuth
input.list=i1
input.i1.class_id=certReqInputImpl
output.list=o1
output.o1.class_id=certOutputImpl
policyset.list=adminCertSet
policyset.adminCertSet.list=1
policyset.adminCertSet.1.constraint.class_id=keyConstraintImpl
policyset.adminCertSet.1.constraint.name=Key Constraint
policyset.adminCertSet.1.constraint.params.keyType=RSA
policyset.adminCertSet.1.constraint.params.keyParameters=1024,2048,3072,4096
policyset.adminCertSet.1.default.class_id=userKeyDefaultImpl
policyset.adminCertSet.1.default.name=Key Default
"""


ACME_STYLE_KEY_POLICY = """\
profileId=testAcmeServer
classId=caEnrollImpl
name=Test ACME Server
desc=RSA 2048+ only
enable=true
visible=false
input.list=i1
input.i1.class_id=certReqInputImpl
output.list=o1
output.o1.class_id=certOutputImpl
policyset.list=serverCertSet
policyset.serverCertSet.list=1
policyset.serverCertSet.1.constraint.class_id=keyConstraintImpl
policyset.serverCertSet.1.constraint.name=Key Constraint
policyset.serverCertSet.1.constraint.params.keyType=RSA
policyset.serverCertSet.1.constraint.params.keyParameters=2048,3072,4096
policyset.serverCertSet.1.default.class_id=userKeyDefaultImpl
policyset.serverCertSet.1.default.name=Key Default
"""


class TestInlineDogtagStyleProfiles:
    """Parse tiny Dogtag-like profiles and validate CSRs against them."""

    def test_admin_cert_style_accepts_2048(self, ipacta_config):
        profile = ProfileParser(
            "testAdminCert.cfg", content=ADMIN_CERT_KEY_POLICY
        ).parse({})
        constraint = _key_constraint_from_profile(profile)
        csr, _ = _make_rsa_csr(2048)
        assert constraint.validate(csr, {}) == []

    def test_acme_style_rejects_1024(self, ipacta_config):
        profile = ProfileParser(
            "testAcmeServer.cfg", content=ACME_STYLE_KEY_POLICY
        ).parse({})
        constraint = _key_constraint_from_profile(profile)
        csr, _ = _make_rsa_csr(1024)
        assert constraint.validate(csr, {})


# ---------------------------------------------------------------------------
# Dogtag KeyConstraintRefactoring: allowedKeys.<alg>.<strength>=true/false
# ---------------------------------------------------------------------------


class TestAllowedKeysUpgrade:
    """Target behavior from Dogtag KeyConstraintRefactoring / KeyConstraintTest.

    These must fail until IPACTA implements allowedKeys.ALG.STRENGTH.
    Assertions use key sizes that pass legacy global min/max (2048-8192) so
    a legacy-only KeyConstraint cannot satisfy them by accident.
    """

    def test_allowed_keys_rsa_strength_accepted(self, ipacta_config):
        constraint = create_constraint(
            "keyConstraintImpl",
            {
                "allowedKeys.RSA.2048": "true",
                "allowedKeys.RSA.3072": "true",
                "allowedKeys.RSA.4096": "true",
            },
        )
        # Prove allowedKeys was consumed, not ignored as unknown kwargs
        assert getattr(constraint, "allowed_keys", None) or any(
            "allowed" in n.lower() for n in vars(constraint)
        ), "KeyConstraint ignored allowedKeys.* parameters"
        csr, _ = _make_rsa_csr(2048)
        assert constraint.validate(csr, {}) == []

    def test_allowed_keys_rsa_strength_rejected(self, ipacta_config):
        constraint = create_constraint(
            "keyConstraintImpl",
            {
                "allowedKeys.RSA.2048": "true",
            },
        )
        # 3072 is within global 2048-8192; legacy code would accept it
        csr, _ = _make_rsa_csr(3072)
        errors = constraint.validate(csr, {})
        assert errors, (
            "3072 must be rejected when only allowedKeys.RSA.2048=true "
            "(legacy global min/max would incorrectly accept it)"
        )

    def test_allowed_keys_all_with_override_false(self, ipacta_config):
        # Dogtag: allowedKeys.RSA.ALL=true + allowedKeys.RSA.3072=false
        constraint = create_constraint(
            "keyConstraintImpl",
            {
                "allowedKeys.RSA.ALL": "true",
                "allowedKeys.RSA.3072": "false",
            },
        )
        csr_ok, _ = _make_rsa_csr(2048)
        assert constraint.validate(csr_ok, {}) == []
        csr_bad, _ = _make_rsa_csr(3072)
        errors = constraint.validate(csr_bad, {})
        assert errors, (
            "3072 must be rejected when ALL=true but RSA.3072=false"
        )

    def test_mixing_legacy_and_allowed_keys_errors(self, ipacta_config):
        # Dogtag: mixing keyType/keyParameters with allowedKeys is an error
        with pytest.raises(Exception):
            create_constraint(
                "keyConstraintImpl",
                {
                    "keyType": "RSA",
                    "keyParameters": "2048,3072",
                    "allowedKeys.RSA.2048": "true",
                },
            )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
