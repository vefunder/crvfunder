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


def test_update_cached_fallback_receiver(alice, bob, charlie, funder, factory):
    # by default both are the same value
    assert funder.cached_fallback_receiver() == factory.fallback_receiver()

    # updating while they're both the same has no effect (value unchanged)
    funder.update_cached_fallback_receiver({"from": alice})
    assert funder.cached_fallback_receiver() == bob

    # update the value in the factory, this does not cause
    # an automatic update, so the funder sc has a stale value
    factory.set_fallback_receiver(charlie, {"from": alice})
    assert funder.cached_fallback_receiver() == bob

    # after calling update we should see the correct value is stored
    funder.update_cached_fallback_receiver({"from": alice})
    assert funder.cached_fallback_receiver() == charlie
