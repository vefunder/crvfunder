from brownie import *

def main():
    return CRVFunder.deploy({'from': accounts[0]})
