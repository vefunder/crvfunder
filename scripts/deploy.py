from brownie import AdminProxy, FundraisingGaugeV1, GaugeFactoryV1, accounts

# can verify against existing ownership proxies
# https://curve.readthedocs.io/ref-addresses.html#ownership-proxies
# https://gov.curve.fi/t/cip-79-replacing-emergency-dao/2004
OWNERSHIP_ADMIN = "0x40907540d8a6C65c637785e8f8B742ae6b0b9968"
EMERGENCY_ADMIN = "0x467947EE34aF926cF1DCac093870f613C96B1E0c"


def main():
    # load an account to use for deployment
    deployer = accounts.load("dev")

    # deploy the ownership proxy
    admin_proxy = AdminProxy.deploy(
        OWNERSHIP_ADMIN, EMERGENCY_ADMIN, {"from": deployer, "priority_fee": "2 gwei"}
    )

    # deploy the implementation
    implementation = FundraisingGaugeV1.deploy(
        admin_proxy, {"from": deployer, "priority_fee": "2 gwei"}
    )

    # deploy the factory
    GaugeFactoryV1.deploy(implementation, {"from": deployer, "priority_fee": "2 gwei"})
