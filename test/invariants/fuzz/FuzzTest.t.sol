// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// import {GreeterGuidedHandlers} from './handlers/guided/Greeter.t.sol';
// import {GreeterUnguidedHandlers} from './handlers/unguided/Greeter.t.sol';
import {SwapperProperties} from './properties/Swapper.t.sol';

// contract FuzzTest is GreeterGuidedHandlers, GreeterUnguidedHandlers, GreeterProperties {}

contract FuzzTest is SwapperProperties {}
