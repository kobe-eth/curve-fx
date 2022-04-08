import os
from scripts.utils import deploy
from brownie import interface


def main():
    router = deploy("JarvisPoolRouter", [])
