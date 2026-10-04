# Copyright (C) 2025  FreeIPA Contributors see COPYING for license

"""OCSPResponder unit tests (no deployment)."""

import configparser
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509 import ocsp
from cryptography.x509.oid import NameOID

import ipacta
from ipacta.ocsp import OCSPResponder


def _rsa():
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


def _name(cn):
    return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, cn)])


def _issue(subject, issuer, key, issuer_key, serial, ca=False):
    now = datetime.now(timezone.utc)
    builder = (
        x509.CertificateBuilder()
        .subject_name(_name(subject))
        .issuer_name(_name(issuer))
        .public_key(key.public_key())
        .serial_number(serial)
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=30))
    )
    if ca:
        builder = builder.add_extension(
            x509.BasicConstraints(ca=True, path_length=None),
            critical=True,
        )
    return builder.sign(issuer_key, hashes.SHA256())


class _FakeCA:
    def __init__(self, ca_cert, ca_key, records):
        self.ca_cert = ca_cert
        self.ca_private_key = ca_key
        self._records = records
        self._next = 100

    def _ensure_ca_loaded(self):
        return None

    def _get_next_serial_number(self):
        self._next += 1
        return self._next

    def get_certificate(self, serial_number):
        return self._records.get(serial_number)


def _responder(tmp_path, ca_cert, ca_key, leaf):
    cfg = configparser.RawConfigParser()
    cfg.add_section("ca")
    cfg.set("ca", "ocsp_signing_key_size", "2048")
    ipacta.set_global_config(cfg)

    record = SimpleNamespace(
        status=SimpleNamespace(value="VALID"),
        revocation_reason=None,
        revoked_at=None,
        certificate=leaf,
    )
    ca = _FakeCA(ca_cert, ca_key, {leaf.serial_number: record})
    return OCSPResponder(
        ca,
        ocsp_cert_path=str(tmp_path / "ocsp.crt"),
        ocsp_key_path=str(tmp_path / "ocsp.key"),
        cache_timeout=60,
    )


def _request(leaf, issuer, algorithm=hashes.SHA256()):
    req = ocsp.OCSPRequestBuilder().add_certificate(
        leaf, issuer, algorithm
    ).build()
    return req.public_bytes(serialization.Encoding.DER)


def test_create_response_good_for_valid_cert(tmp_path):
    """A valid issued cert must get a successful OCSP 'good' response."""
    ca_key = _rsa()
    ca_cert = _issue("CA", "CA", ca_key, ca_key, 1, ca=True)
    leaf_key = _rsa()
    leaf = _issue("leaf", "CA", leaf_key, ca_key, 2)

    responder = _responder(tmp_path, ca_cert, ca_key, leaf)
    der = responder.create_response(_request(leaf, ca_cert))
    response = ocsp.load_der_ocsp_response(der)

    assert response.response_status == ocsp.OCSPResponseStatus.SUCCESSFUL
    assert response.certificate_status == ocsp.OCSPCertStatus.GOOD
    assert response.serial_number == leaf.serial_number


def test_create_response_accepts_ipalib_certificate_wrapper(tmp_path):
    """LDAP storage returns IPACertificate; OCSP must unwrap .cert."""
    ca_key = _rsa()
    ca_cert = _issue("CA", "CA", ca_key, ca_key, 1, ca=True)
    leaf_key = _rsa()
    leaf = _issue("leaf", "CA", leaf_key, ca_key, 2)

    class _IPACert:
        def __init__(self, cert):
            self.cert = cert

    cfg = configparser.RawConfigParser()
    cfg.add_section("ca")
    cfg.set("ca", "ocsp_signing_key_size", "2048")
    ipacta.set_global_config(cfg)

    record = SimpleNamespace(
        status=SimpleNamespace(value="VALID"),
        revocation_reason=None,
        revoked_at=None,
        certificate=_IPACert(leaf),
    )
    ca = _FakeCA(ca_cert, ca_key, {leaf.serial_number: record})
    responder = OCSPResponder(
        ca,
        ocsp_cert_path=str(tmp_path / "ocsp.crt"),
        ocsp_key_path=str(tmp_path / "ocsp.key"),
        cache_timeout=60,
    )
    der = responder.create_response(_request(leaf, ca_cert))
    response = ocsp.load_der_ocsp_response(der)
    assert response.response_status == ocsp.OCSPResponseStatus.SUCCESSFUL
    assert response.certificate_status == ocsp.OCSPCertStatus.GOOD
