"""platform_info() reads the environment the template sets, and nothing else."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

import app  # noqa: E402


def test_lists_split_on_commas(monkeypatch):
    monkeypatch.setenv("PRIVATE_SUBNET_IDS", "subnet-a,subnet-b")
    monkeypatch.setenv("PUBLIC_SUBNET_IDS", "")
    info = app.platform_info()
    assert info["infrastructure"]["vpc"]["private_subnet_ids"] == ["subnet-a", "subnet-b"]
    assert info["infrastructure"]["vpc"]["public_subnet_ids"] == []


def test_every_value_comes_from_the_environment(monkeypatch):
    monkeypatch.setenv("STAGE", "dev")
    monkeypatch.setenv("VPC_LINK_ID", "vpclink-1")
    monkeypatch.setenv("APPCONFIG_APPLICATION_ID", "app-1")
    info = app.platform_info()
    assert info["stage"] == "dev"
    assert info["infrastructure"]["vpc_link"]["id"] == "vpclink-1"
    assert info["infrastructure"]["appconfig"]["application_id"] == "app-1"
