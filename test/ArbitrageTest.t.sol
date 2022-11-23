pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

import { IFactory } from "numoen-core/interfaces/IFactory.sol";
import { IUniswapV2Factory } from "../src/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../src/interfaces/IUniswapV2Pair.sol";
import { ILendgine } from "numoen-core/interfaces/ILendgine.sol";
import { IPair } from "numoen-core/interfaces/IPair.sol";
import { NumoenLibrary } from "numoen-manager/libraries/NumoenLibrary.sol";
import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

import { Arbitrage } from "../src/Arbitrage.sol";

contract ArbitrageTest is Test {
    IFactory public immutable factory = IFactory(0x8780898Cf5f3E3b20714b0AAEA198817b1cA481d);
    IUniswapV2Factory public immutable uniFactory = IUniswapV2Factory(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);

    ILendgine public lendgine;
    IPair public pair;
    IUniswapV2Pair public uniPair;
    MockERC20 public immutable base;
    MockERC20 public immutable speculative;
    uint256 public immutable upperBound = 5 ether;
    address public immutable cuh;

    Arbitrage public immutable arbitrage;

    constructor() {
        arbitrage = new Arbitrage(address(factory), address(uniFactory));
        cuh = mkaddr("cuh");

        speculative = new MockERC20();
        base = new MockERC20();
    }

    function setUp() public {
        (address _lendgine, address _pair) = factory.createLendgine(
            address(base),
            address(speculative),
            18,
            18,
            upperBound
        );
        lendgine = ILendgine(_lendgine);
        pair = IPair(_pair);

        base.mint(_pair, 90 ether);
        speculative.mint(_pair, 40 ether);
        pair.mint(10 ether);

        address _uniPair = uniFactory.createPair(address(base), address(speculative));
        uniPair = IUniswapV2Pair(_uniPair);
        base.mint(_uniPair, 100 ether);
        speculative.mint(_uniPair, 100 ether);
        uniPair.mint(address(this));
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }

    function testBasicArb() public {
        uint256 priceBefore = NumoenLibrary.reservesToPrice(speculative.balanceOf(address(pair)), 10 ether, upperBound);
        uint256 uniPriceBefore = PRBMathUD60x18.div(
            base < speculative ? speculative.balanceOf(address(uniPair)) : base.balanceOf(address(uniPair)),
            base < speculative ? base.balanceOf(address(uniPair)) : speculative.balanceOf(address(uniPair))
        );

        arbitrage.arb0(
            Arbitrage.ArbParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                arbAmount: 5 ether,
                recipient: cuh
            })
        );

        uint256 priceAfter = NumoenLibrary.reservesToPrice(speculative.balanceOf(address(pair)), 10 ether, upperBound);
        uint256 uniPriceAfter = PRBMathUD60x18.div(
            base < speculative ? speculative.balanceOf(address(uniPair)) : base.balanceOf(address(uniPair)),
            base < speculative ? base.balanceOf(address(uniPair)) : speculative.balanceOf(address(uniPair))
        );

        assert(priceAfter < priceBefore);
        assert(uniPriceAfter > uniPriceBefore);

        assert(base.balanceOf(cuh) > 0);
        assertEq(speculative.balanceOf(cuh), 0);

        assertEq(speculative.balanceOf(address(arbitrage)), 0);
        assertEq(base.balanceOf(address(arbitrage)), 0);
    }
}
