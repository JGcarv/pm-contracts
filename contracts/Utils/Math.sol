pragma solidity ^0.4.15;


/// @title Math library - Allows calculation of logarithmic and exponential functions
/// @author Alan Lu - <alan.lu@gnosis.pm>
/// @author Stefan George - <stefan@gnosis.pm>
library Math {

    /*
     *  Constants
     */
    // This is equal to 1 in our calculations
    uint public constant ONE =  0x10000000000000000;
    uint public constant LN2 = 0xb17217f7d1cf79ac;
    uint public constant LOG2_E = 0x171547652b82fe177;

    /*
     *  Public functions
     */
    /// @dev Returns natural exponential function value of given x
    /// @param x x
    /// @return e**x
    function exp(int x)
        public
        constant
        returns (uint)
    {
        // revert if x is > MAX_POWER, where
        // MAX_POWER = int(mp.floor(mp.log(mpf(2**256 - 1) / ONE) * ONE))
        require(x <= 2454971259878909886679);
        // return 0 if exp(x) is tiny, using
        // MIN_POWER = int(mp.floor(mp.log(mpf(1) / ONE) * ONE))
        if (x <= -818323753292969962227)
            return 0;

        // Transform so that e^x -> 2^x
        var (lower, upper) = pow2Bounds(x * int(ONE) / int(LN2));
        return (upper - lower) / 2 + lower;
    }

    /// @dev Returns bounds for value of 2**x given x
    /// @param x exponent in fixed point
    /// @return {
    ///   "lower": "lower bound of 2**x in fixed point",
    ///   "upper": "upper bound of 2**x in fixed point"
    /// }
    function pow2Bounds(int x)
        public
        constant
        returns (uint lower, uint upper)
    {
        // revert if x is > MAX_POWER, where
        // MAX_POWER = int(mp.floor(mp.log(mpf(2**256 - 1) / ONE, 2) * ONE))
        require(x <= 3541774862152233910271);
        // return 0 if exp(x) is tiny, using
        // MIN_POWER = int(mp.floor(mp.log(mpf(1) / ONE, 2) * ONE))
        if (x < -1180591620717411303424)
            return (0, 0);

        // 2^x = 2^(whole(x)+1) * 2^(frac(x)-1)
        //       ^^^^^^^^^^^^^^ is a bit shift
        // so Taylor expand on z = frac(x)-1, -1 <= z < 0
        int shift;
        int z;
        if (x <= 0) {
            shift = x / int(ONE);
            z = x % int(ONE);
        }
        else {
            shift = x / int(ONE) + 1;
            z = x % int(ONE) - 1;
        }
        // 2^x = 1 + (ln 2) x + (ln 2)^2/2! x^2 + ...
        //
        // Can generate the z coefficients using mpmath and the following lines
        // >>> from mpmath import mp
        // >>> mp.dps = 100
        // >>> coeffs = [mp.log(2)**i / mp.factorial(i) for i in range(1, 21)]
        // >>> shifts = [64 - int(mp.log(c, 2)) for c in coeffs]
        // >>> print('\n'.join(hex(int(c * (1 << s))) + ', ' + str(s) for c, s in zip(coeffs, shifts)))
        int result = int(ONE);
        int zpow = z;
        result += 0xb17217f7d1cf79ab * zpow >> 64;
        zpow = zpow * z / int(ONE);
        result += 0xf5fdeffc162c7543 * zpow >> 66;
        zpow = zpow * z / int(ONE);
        result += 0xe35846b82505fc59 * zpow >> 68;
        zpow = zpow * z / int(ONE);
        result += 0x9d955b7dd273b94e * zpow >> 70;
        zpow = zpow * z / int(ONE);
        result += 0xaec3ff3c53398883 * zpow >> 73;
        zpow = zpow * z / int(ONE);
        result += 0xa184897c363c3b7a * zpow >> 76;
        zpow = zpow * z / int(ONE);
        result += 0xffe5fe2c45863435 * zpow >> 80;
        zpow = zpow * z / int(ONE);
        result += 0xb160111d2e411fec * zpow >> 83;
        zpow = zpow * z / int(ONE);
        result += 0xda929e9caf3e1ed2 * zpow >> 87;
        zpow = zpow * z / int(ONE);
        result += 0xf267a8ac5c764fb7 * zpow >> 91;
        zpow = zpow * z / int(ONE);
        result += 0xf465639a8dd92607 * zpow >> 95;
        zpow = zpow * z / int(ONE);
        result += 0xe1deb287e14c2f15 * zpow >> 99;
        zpow = zpow * z / int(ONE);
        result += 0xc0b0c98b3687cb14 * zpow >> 103;
        zpow = zpow * z / int(ONE);
        result += 0x98a4b26ac3c54b9f * zpow >> 107;
        zpow = zpow * z / int(ONE);
        result += 0xe1b7421d82010f33 * zpow >> 112;
        zpow = zpow * z / int(ONE);
        result += 0x9c744d73cfc59c91 * zpow >> 116;
        zpow = zpow * z / int(ONE);
        result += 0xcc2225a0e12d3eab * zpow >> 121;
        zpow = zpow * z / int(ONE);
        zpow = 0xfb8bb5eda1b4aeb9 * zpow >> 126 + 1;
        assert(zpow >= 0);
        if (shift >= 0) {
            if (result >> (256-shift) == 0) {
                lower = uint(result) << shift;
                zpow <<= shift; // todo: is this safe?
                if (safeToAdd(lower, uint(zpow)))
                    upper = lower + uint(zpow);
                else
                    upper = 2**256-1;
                return;
            }
            else
                return (2**256-1, 2**256-1);
        }
        zpow = zpow >> (-shift) + 1;
        lower = uint(result) >> (-shift);
        upper = lower + uint(zpow);
        return;
    }

    /// @dev Returns natural logarithm value of given x
    /// @param x x
    /// @return ln(x)
    function ln(uint x)
        public
        constant
        returns (int)
    {
        require(x > 0);
        // binary search for floor(log2(x))
        int ilog2 = floorLog2(x);
        int z;
        if (ilog2 < 0)
            z = int(x << uint(-ilog2));
        else
            z = int(x >> uint(ilog2));
        // z = x * 2^-⌊log₂x⌋
        // so 1 <= z < 2
        // and ln z = ln x - ⌊log₂x⌋/log₂e
        // so just compute ln z using artanh series
        // and calculate ln x from that
        int term = (z - int(ONE)) * int(ONE) / (z + int(ONE));
        int halflnz = term;
        int termpow = term * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 3;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 5;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 7;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 9;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 11;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 13;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 15;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 17;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 19;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 21;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 23;
        termpow = termpow * term / int(ONE) * term / int(ONE);
        halflnz += termpow / 25;
        return (ilog2 * int(ONE)) * int(ONE) / int(LOG2_E) + 2 * halflnz;
    }

    /// @dev Returns base 2 logarithm value of given x
    /// @param x x
    /// @return logarithmic value
    function floorLog2(uint x) returns (int y){
       assembly {
            let arg := x
            x := sub(x,1)
            x := or(x, div(x, 0x02))
            x := or(x, div(x, 0x04))
            x := or(x, div(x, 0x10))
            x := or(x, div(x, 0x100))
            x := or(x, div(x, 0x10000))
            x := or(x, div(x, 0x100000000))
            x := or(x, div(x, 0x10000000000000000))
            x := or(x, div(x, 0x100000000000000000000000000000000))
            x := add(x, 1)
            let m := mload(0x40)
            mstore(m,           0xf8f9cbfae6cc78fbefe7cdc3a1793dfcf4f0e8bbd8cec470b6a28a7a5a3e1efd)
            mstore(add(m,0x20), 0xf5ecf1b3e9debc68e1d9cfabc5997135bfb7a7a3938b7b606b5b4b3f2f1f0ffe)
            mstore(add(m,0x40), 0xf6e4ed9ff2d6b458eadcdf97bd91692de2d4da8fd2d0ac50c6ae9a8272523616)
            mstore(add(m,0x60), 0xc8c0b887b0a8a4489c948c7f847c6125746c645c544c444038302820181008ff)
            mstore(add(m,0x80), 0xf7cae577eec2a03cf3bad76fb589591debb2dd67e0aa9834bea6925f6a4a2e0e)
            mstore(add(m,0xa0), 0xe39ed557db96902cd38ed14fad815115c786af479b7e83247363534337271707)
            mstore(add(m,0xc0), 0xc976c13bb96e881cb166a933a55e490d9d56952b8d4e801485467d2362422606)
            mstore(add(m,0xe0), 0x753a6d1b65325d0c552a4d1345224105391a310b29122104190a110309020100)
            mstore(0x40, add(m, 0x100))
            let magic := 0x818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff
            let shift := 0x100000000000000000000000000000000000000000000000000000000000000
            let a := div(mul(x, magic), shift)
            y := div(mload(add(m,sub(255,a))), shift)
            y := sub(add(y, mul(256, gt(arg, 0x8000000000000000000000000000000000000000000000000000000000000000))), 64)
        }  
    }


    /// @dev Returns maximum of an array
    /// @param nums Numbers to look through
    /// @return Maximum number
    function max(int[] nums)
        public
        constant
        returns (int max)
    {
        require(nums.length > 0);
        max = -2**255;
        for (uint i = 0; i < nums.length; i++)
            if (nums[i] > max)
                max = nums[i];
    }

    /// @dev Returns whether an add operation causes an overflow
    /// @param a First addend
    /// @param b Second addend
    /// @return Did no overflow occur?
    function safeToAdd(uint a, uint b)
        public
        constant
        returns (bool)
    {
        return a + b >= a;
    }

    /// @dev Returns whether a subtraction operation causes an underflow
    /// @param a Minuend
    /// @param b Subtrahend
    /// @return Did no underflow occur?
    function safeToSub(uint a, uint b)
        public
        constant
        returns (bool)
    {
        return a >= b;
    }

    /// @dev Returns whether a multiply operation causes an overflow
    /// @param a First factor
    /// @param b Second factor
    /// @return Did no overflow occur?
    function safeToMul(uint a, uint b)
        public
        constant
        returns (bool)
    {
        return b == 0 || a * b / b == a;
    }

    /// @dev Returns sum if no overflow occurred
    /// @param a First addend
    /// @param b Second addend
    /// @return Sum
    function add(uint a, uint b)
        public
        constant
        returns (uint)
    {
        require(safeToAdd(a, b));
        return a + b;
    }

    /// @dev Returns difference if no overflow occurred
    /// @param a Minuend
    /// @param b Subtrahend
    /// @return Difference
    function sub(uint a, uint b)
        public
        constant
        returns (uint)
    {
        require(safeToSub(a, b));
        return a - b;
    }

    /// @dev Returns product if no overflow occurred
    /// @param a First factor
    /// @param b Second factor
    /// @return Product
    function mul(uint a, uint b)
        public
        constant
        returns (uint)
    {
        require(safeToMul(a, b));
        return a * b;
    }

    /// @dev Returns whether an add operation causes an overflow
    /// @param a First addend
    /// @param b Second addend
    /// @return Did no overflow occur?
    function safeToAdd(int a, int b)
        public
        constant
        returns (bool)
    {
        return (b >= 0 && a + b >= a) || (b < 0 && a + b < a);
    }

    /// @dev Returns whether a subtraction operation causes an underflow
    /// @param a Minuend
    /// @param b Subtrahend
    /// @return Did no underflow occur?
    function safeToSub(int a, int b)
        public
        constant
        returns (bool)
    {
        return (b >= 0 && a - b <= a) || (b < 0 && a - b > a);
    }

    /// @dev Returns whether a multiply operation causes an overflow
    /// @param a First factor
    /// @param b Second factor
    /// @return Did no overflow occur?
    function safeToMul(int a, int b)
        public
        constant
        returns (bool)
    {
        return (b == 0) || (a * b / b == a);
    }

    /// @dev Returns sum if no overflow occurred
    /// @param a First addend
    /// @param b Second addend
    /// @return Sum
    function add(int a, int b)
        public
        constant
        returns (int)
    {
        require(safeToAdd(a, b));
        return a + b;
    }

    /// @dev Returns difference if no overflow occurred
    /// @param a Minuend
    /// @param b Subtrahend
    /// @return Difference
    function sub(int a, int b)
        public
        constant
        returns (int)
    {
        require(safeToSub(a, b));
        return a - b;
    }

    /// @dev Returns product if no overflow occurred
    /// @param a First factor
    /// @param b Second factor
    /// @return Product
    function mul(int a, int b)
        public
        constant
        returns (int)
    {
        require(safeToMul(a, b));
        return a * b;
    }
}
