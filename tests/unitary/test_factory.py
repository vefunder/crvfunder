import brownie
from brownie import ZERO_ADDRESS


def test_set_fallback_receiver_only_owner(factory, bob):
    assert factory.owner() is not bob
    with brownie.reverts():
        factory.set_fallback_receiver(bob, {"from": bob})


def test_initial_fallback_receiver_bob(factory, bob):
    assert factory.fallback_receiver() == bob


def test_set_fallback_receiver_logs_event(factory, alice, bob, charlie):
    tx = factory.set_fallback_receiver(charlie, {"from": alice})
    assert tx.events["UpdateFallbackReceiver"]["_old_fallback"] == bob
    assert tx.events["UpdateFallbackReceiver"]["_new_fallback"] == charlie


def test_set_fallback_receiver_sets(factory, alice, charlie):
    factory.set_fallback_receiver(charlie, {"from": alice})
    assert factory.fallback_receiver() == charlie


def test_set_implementation_only_owner(factory, bob):
    with brownie.reverts():
        factory.set_implementation(factory, {"from": bob})


def test_set_implementation_logs_event(factory, alice):
    tx = factory.set_implementation(factory, {"from": alice})
    assert tx.events["UpdateImplementation"]["_old_implementation"] == ZERO_ADDRESS
    assert tx.events["UpdateImplementation"]["_new_implementation"] == factory


def test_set_implementation_sets(factory, alice):
    factory.set_implementation(factory, {"from": alice})
    assert factory.implementation() == factory


def test_owner_is_alice(factory, alice):
    assert factory.owner() == alice


def test_transfer_only_owner(factory, bob):
    with brownie.reverts():
        factory.commit_transfer_ownership(bob, {"from": bob})


def test_transfer_future_owner_sets(factory, alice, bob):
    factory.commit_transfer_ownership(bob, {"from": alice})
    assert factory.future_owner() == bob


def test_transfer_owner_accept(factory, alice, bob):
    factory.commit_transfer_ownership(bob, {"from": alice})
    factory.accept_transfer_ownership({"from": bob})
    assert factory.owner() == bob


def test_transfer_owner_accept_event(factory, alice, bob):
    factory.commit_transfer_ownership(bob, {"from": alice})
    tx = factory.accept_transfer_ownership({"from": bob})
    assert tx.events["TransferOwnership"]["_old_owner"] == alice
    assert tx.events["TransferOwnership"]["_new_owner"] == bob
