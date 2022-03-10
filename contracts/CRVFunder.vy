# @version 0.3.1
"""
@title veFunder
@notice Custom gauge directing emissions to specified wallet
"""


interface CRV20:
    def rate() -> uint256: view
    def future_epoch_time_write() -> uint256: nonpayable

interface Factory:
    def owner() -> address: view

interface GaugeController:
    def checkpoint_gauge(_gauge: address): nonpayable
    def gauge_relative_weight(_gauge: address, _time: uint256) -> uint256: view


event Checkpoint:
    _timestamp: uint256
    _new_emissions: uint256

event TransferOwnership:
    _old_owner: indexed(address)
    _new_owner: indexed(address)


CRV: constant(address) = 0xD533a949740bb3306d119CC777fa900bA034cd52
GAUGE_CONTROLLER: constant(address) = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB
GRANT_COUNCIL_MULTISIG: constant(address) = 0xc420C9d507D0E038BD76383AaADCAd576ed0073c

WEEK: constant(uint256) = 604800
YEAR: constant(uint256) = 86400 * 365

# taken from CRV20 to allow calculating locally
RATE_DENOMINATOR: constant(uint256) = 10 ** 18
RATE_REDUCTION_COEFFICIENT: constant(uint256) = 1189207115002721024  # 2 ** (1/4) * 1e18
RATE_REDUCTION_TIME: constant(uint256) = YEAR

# [uint216 inflation_rate][uint40 future_epoch_time]
inflation_params: uint256

# _user => accumulated CRV
integrate_fraction: public(HashMap[address, uint256])
last_checkpoint: public(uint256)

fund_recipient: public(address)
funding_end_timestamp: public(uint256)
max_integrate_fraction: public(uint256)

factory: public(address)


@external
def __init__():
    # prevent initialization of the implementation contract
    self.factory = 0x000000000000000000000000000000000000dEaD


@external
def user_checkpoint(_user: address) -> bool:
    """
    @notice Checkpoint the gauge updating total emissions
    @param _user The user to checkpoint and update accumulated emissions for
    """
    # timestamp of the last checkpoint and start point for calculating new emissions
    prev_week_time: uint256 = self.last_checkpoint

    # if time has not advanced since the last checkpoint
    if block.timestamp == prev_week_time:
        return True

    # either the start of the next week or the current timestamp
    week_time: uint256 = min((prev_week_time + WEEK) / WEEK * WEEK, block.timestamp)

    # if funding duration has expired, direct to treasury:
    fund_recipient: address = self.fund_recipient
    if block.timestamp >= self.funding_end_timestamp:
        fund_recipient = GRANT_COUNCIL_MULTISIG

    # load and unpack inflation params
    inflation_params: uint256 = self.inflation_params
    rate: uint256 = shift(inflation_params, -40)
    future_epoch_time: uint256 = bitwise_and(inflation_params, 2 ** 40 - 1)

    # track total new emissions while we loop
    new_emissions: uint256 = 0

    # checkpoint the gauge filling in any missing gauge data across weeks
    GaugeController(GAUGE_CONTROLLER).checkpoint_gauge(self)

    # iterate over at maximum 512 weeks
    for i in range(512):
        dt: uint256 = week_time - prev_week_time
        w: uint256 = GaugeController(GAUGE_CONTROLLER).gauge_relative_weight(self, prev_week_time / WEEK * WEEK)

        if prev_week_time <= future_epoch_time and future_epoch_time < week_time:
            # calculate up to the epoch using the old rate
            new_emissions += rate * w * (future_epoch_time - prev_week_time) / 10 ** 18
            # update the rate in memory
            rate = rate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT
            # calculate past the epoch to the start of the next week
            new_emissions += rate * w * (week_time - future_epoch_time) / 10 ** 18
            # update the new future epoch time
            future_epoch_time += RATE_REDUCTION_TIME
            # update storage
            self.inflation_params = shift(rate, 40) + future_epoch_time
        else:
            new_emissions += rate * w * dt / 10 ** 18

        if week_time == block.timestamp:
            break
        # update timestamps for tracking timedelta
        prev_week_time = week_time
        week_time = min(week_time + WEEK, block.timestamp)

    # cap accumulated emissions only for fund receipient
    # todo: check with skelletor if this is the right approach
    if fund_recipient == self.fund_recipient:
        new_emissions = max(self.max_integrate_fraction, new_emissions)

    self.integrate_fraction[fund_recipient] += new_emissions
    self.last_checkpoint = block.timestamp

    log Checkpoint(block.timestamp, new_emissions)
    return True


@external
def set_killed(_is_killed: bool):
    """
    @notice Set the gauge status
    @dev Inflation params are modified accordingly to disable/enable emissions
    """
    assert msg.sender == Factory(self.factory).owner()

    if _is_killed:
        self.inflation_params = 0
    else:
        self.inflation_params = shift(CRV20(CRV).rate(), 40) + CRV20(CRV).future_epoch_time_write()


@view
@external
def inflation_rate() -> uint256:
    """
    @notice Get the locally stored inflation rate
    """
    return shift(self.inflation_params, -40)


@view
@external
def future_epoch_time() -> uint256:
    """
    @notice Get the locally stored timestamp of the inflation rate epoch end
    """
    return bitwise_and(self.inflation_params, 2 ** 40 - 1)


@external
def initialize(
    _fund_recipient: address,
    _funding_end_timestamp: uint256,
    _max_integrate_fraction: uint256
):
    """
    @notice Proxy initializer method
    @dev Placed last in the source file to save some gas, this fn is called only once.
        Additional checks should be made by the DAO before voting in this gauge, specifically
        to make sure that `_fund_recipient` is capable of collecting emissions.
    @param _fund_recipient The address which will receive CRV emissions
    @param _funding_end_timestamp The timestamp at which emissions will redirect to
        the Curve Grant Council Multisig
    @param _max_integrate_fraction The maximum amount of emissions which `_fund_recipient` will
        receive
    """
    assert self.factory == ZERO_ADDRESS  # dev: already initialized

    self.factory = msg.sender

    self.fund_recipient = _fund_recipient
    self.funding_end_timestamp = _funding_end_timestamp
    self.max_integrate_fraction = _max_integrate_fraction

    self.inflation_params = shift(CRV20(CRV).rate(), 40) + CRV20(CRV).future_epoch_time_write()
    self.last_checkpoint = block.timestamp
