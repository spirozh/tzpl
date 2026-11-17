-- Digit separators: '_' may separate digits in any numeric literal. The
-- separators are lexical only -- they never reach the value -- and are
-- allowed exactly between two digits.

println(1_000);              -- 1000
println(1_0_0);              -- 100
println(123_456_789);        -- 123456789
println(0xFF_FF);            -- 65535
println(0xdead_beef);        -- 3735928559
println(0x7fff_ffff);        -- 2147483647
println(1_000.000_5);        -- 1000.0005
println(1_5.5e1_0);          -- 1.55e11
println(3_000/2_000);        -- 3/2 (reduced)
println(1_0i);               -- 0+10i
println(-1_000);             -- -1000
println(1_000 toFloat);      -- 1000.0
println(0xF_F);              -- 255
println(0X1_F);              -- 31
println(1_0e1_0);            -- 1e11
println(1e-1_0);             -- 1e-10
println(1.5_0i);             -- 0+1.5i
println(1_0e1_0i);           -- 0+1e11i
println(9_223_372_036_854_775_807);  -- the largest Int
println((1_0..1_2) toArray); -- [10, 11, 12]
let a = (0..10) toArray;
println(a[1_0]);             -- 10

-- A separated literal is the same value as the unseparated one.
println(1_000 == 1000);
println(0xFF_FF == 65535);
println(1_000.5 == 1000.5);
println(1_0i == 10i);

-- Tuple indexes take separators too: t.1_0 is element ten.
let t = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11);
println(t.0_0);              -- 0
println(t.1_0);              -- 10
println(t . 1_0);            -- 10 (spaced field access, not the tight path)
