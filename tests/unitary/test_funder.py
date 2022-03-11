import brownie


def test_owner_can_kill(funder, factory, alice):
    assert factory.owner() == alice
    funder.set_killed(True, {"from": alice})


def test_nonowner_cannot_kill(funder, factory, bob):
    assert factory.owner() != bob
    with brownie.reverts():
        funder.set_killed(True, {"from": bob})


def test_deploys_with_inflation(funder, alice):
    assert funder.inflation_rate() > 0


def test_killing_ends_inflation(funder, factory, alice):
    funder.set_killed(True, {"from": alice})
    assert funder.inflation_rate() == 0
