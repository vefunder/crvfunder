# @version 0.3.1
"""
@title veFunder
@notice Custom gauge directing emissions to specified wallet
"""


interface CRV20:
    def rate() -> uint256: view
    def future_epoch_time_write() -> uint256: nonpayable

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
TREASURY_ADDRESS: constant(address) = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB  # todo: add treasury adddress here

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

owner: public(address)
future_owner: public(address)
fund_receipient: public(address)

funding_end_timestamp: public(uint256)
max_integrate_fraction: public(uint256)


@external
def __init__(
    fund_receipient: address,
    funding_end_timestamp: uint256,
    max_integrate_fraction: uint256
):
    self.fund_receipient = fund_receipient
    self.funding_end_timestamp = funding_end_timestamp
    self.max_integrate_fraction = max_integrate_fraction

    self.inflation_params = shift(CRV20(CRV).rate(), 40) + CRV20(CRV).future_epoch_time_write()
    self.last_checkpoint = block.timestamp

    self.owner = msg.sender
    log TransferOwnership(ZERO_ADDRESS, msg.sender)


@external
def user_checkpoint(_user: address) -> bool:
    """
    @notice Checkpoint the gauge updating total emissions
    @param _user The user to checkpoint and update accumulated emissions for
    """
    # timestamp of the last checkpoint
    last_checkpoint: uint256 = self.last_checkpoint

    # if time has not advanced since the last checkpoint
    if block.timestamp == last_checkpoint:
        return True

    # if funding duration has expired, direct to treasury:
    fund_receipient: address = self.fund_receipient
    if block.timestamp >= self.funding_end_timestamp:
        fund_receipient = TREASURY_ADDRESS

    # checkpoint the gauge filling in gauge data across weeks
    GaugeController(GAUGE_CONTROLLER).checkpoint_gauge(self)

    # load and unpack inflation params
    inflation_params: uint256 = self.inflation_params
    rate: uint256 = shift(inflation_params, -40)
    future_epoch_time: uint256 = bitwise_and(inflation_params, 2 ** 40 - 1)

    # initialize variables for tracking timedelta between weeks
    prev_week_time: uint256 = last_checkpoint
    # either the start of the next week or the current timestamp
    week_time: uint256 = min((last_checkpoint + WEEK) / WEEK * WEEK, block.timestamp)

    # track total new emissions while we loop
    new_emissions: uint256 = 0

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
    if fund_receipient == self.fund_receipient:
        new_emissions = max(self.max_integrate_fraction, new_emissions)

    self.integrate_fraction[fund_receipient] += new_emissions
    self.last_checkpoint = block.timestamp

    log Checkpoint(block.timestamp, new_emissions)
    return True


@external
def set_killed(_is_killed: bool):
    """
    @notice Set the gauge status
    @dev Inflation params are modified accordingly to disable/enable emissions
    """
    assert msg.sender == self.owner

    if _is_killed:
        self.inflation_params = 0
    else:
        self.inflation_params = shift(CRV20(CRV).rate(), 40) + CRV20(CRV).future_epoch_time_write()


@external
def commit_transfer_ownership(_future_owner: address):
    """
    @notice Commit the transfer of ownership to `_future_owner`
    @param _future_owner The account to commit as the future owner
    """
    assert msg.sender == self.owner  # dev: only owner

    self.future_owner = _future_owner


@external
def accept_transfer_ownership():
    """
    @notice Accept the transfer of ownership
    @dev Only the committed future owner can call this function
    """
    assert msg.sender == self.future_owner  # dev: only future owner

    log TransferOwnership(self.owner, msg.sender)
    self.owner = msg.sender
