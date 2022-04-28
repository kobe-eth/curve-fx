from brownie import CurveFxRouter

name_to_artifact = {"CurveFxRouter": CurveFxRouter}


def contract_name_to_artifact(name):
    return name_to_artifact[name]
