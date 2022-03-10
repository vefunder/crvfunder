import pytest


@pytest.fixture(scope="module")
def curve_dao(pm):
    return pm("curvefi/curve-dao-contracts@1.3.0")


@pytest.fixture(scope="module")
def crv20(alice, chain, curve_dao):
    crv = curve_dao.ERC20CRV.deploy("Curve DAO Token", "CRV", 18, {"from": alice})
    chain.sleep(86400 * 14)  # let emissions begin
    crv.update_mining_parameters({"from": alice})
    return crv


@pytest.fixture(scope="module")
def voting_escrow(alice, crv20, curve_dao):
    return curve_dao.VotingEscrow.deploy(crv20, "Dummy VECRV", "veCRV", "v1", {"from": alice})


@pytest.fixture(scope="module")
def gauge_controller(alice, crv20, voting_escrow, curve_dao):
    return curve_dao.GaugeController.deploy(crv20, voting_escrow, {"from": alice})


@pytest.fixture(scope="module")
def minter(alice, crv20, gauge_controller, curve_dao):
    minter = curve_dao.Minter.deploy(crv20, gauge_controller, {"from": alice})
    crv20.set_minter(minter, {"from": alice})
    return minter
