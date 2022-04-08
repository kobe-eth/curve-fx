from brownie import JarvisPoolRouter

name_to_artifact = {"JarvisPoolRouter": JarvisPoolRouter}


def contract_name_to_artifact(name):
    return name_to_artifact[name]
