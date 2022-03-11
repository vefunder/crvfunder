from brownie import Factory, accounts

FACTORY_ADDR = ""
CALLER = accounts.load("dev")

# account to receive emissions
RECEIVER = ""
# maximum amount of emissions to receiver (to the correct precision)
MAX_EMISSIONS = 200 * 10**18


def main():
    # change to be account
    factory = Factory.at(FACTORY_ADDR)

    tx = factory.deploy(RECEIVER, MAX_EMISSIONS, {"from": CALLER, "priority_fee": "2 gwei"})
    print(f"Funding Gauge deployed at: {tx.events['NewFunder']['_funder_instance']}")
