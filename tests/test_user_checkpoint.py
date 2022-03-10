import pytest
from brownie import chain

WEEK = 7 * 86400
YEAR = 365 * 86400


@pytest.mark.skip_coverage
def test_emissions_against_expected(alice, gauge_controller, funder, crv20):
    gauge_controller.add_type("Test", 10**18, {"from": alice})
    gauge_controller.add_gauge(funder, 0, 10**18, {"from": alice})

    rate = crv20.rate()
    future_epoch_time = crv20.future_epoch_time_write({"from": alice}).return_value
    total_emissions = 0

    prev_week_time = funder.last_checkpoint()
    chain.mine(timedelta=2 * YEAR)
    tx = funder.user_checkpoint(alice, {"from": alice})

    while True:
        week_time = min((prev_week_time + WEEK) // WEEK * WEEK, tx.timestamp)
        gauge_weight = gauge_controller.gauge_relative_weight(funder, prev_week_time)

        if prev_week_time <= future_epoch_time < week_time:
            total_emissions += (
                gauge_weight * rate * (future_epoch_time - prev_week_time) // 10**18
            )
            rate = rate * 10**18 // 1189207115002721024
            total_emissions += gauge_weight * rate * (week_time - future_epoch_time) // 10**18
            future_epoch_time += YEAR
        else:
            total_emissions += gauge_weight * rate * (week_time - prev_week_time) // 10**18

        if week_time == tx.timestamp:
            break

        prev_week_time = week_time

    assert total_emissions == funder.integrate_fraction(alice)
