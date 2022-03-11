from brownie import CRVFunder, Factory, accounts


def main():
    # load an account to use for deployment
    deployer = accounts.load("dev")
    # need to put this somewhere everyone can verify is correct
    fallback_receiver = "0xc420C9d507D0E038BD76383AaADCAd576ed0073c"  # Curve Grant Council Multisig

    # deploy the factory
    factory = Factory.deploy(fallback_receiver, {"from": deployer, "priority_fee": "2 gwei"})
    implementation = CRVFunder.deploy({"from": deployer, "priority_fee": "2 gwei"})

    # set the implementation
    factory.set_implementation(implementation, {"from": deployer, "priority_fee": "2 gwei"})
