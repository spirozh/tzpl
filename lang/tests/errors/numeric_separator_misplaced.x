-- A digit separator must sit directly between two digits: at least one digit
-- before it and at least one after it. Anything else is a lexer error, with
-- the caret on the offending '_'.
println(1_);              -- trailing
println(1__0);            -- doubled
println(1.000_);          -- trailing after the fraction
println(1.000_e5);        -- before the exponent marker
println(1e_5);            -- directly after the exponent marker
println(1e5_);            -- trailing after the exponent digits
println(1e+_5);           -- directly after the exponent sign
println(1_i);             -- before the imaginary suffix
println(3_/2_000);        -- trailing in the numerator
println(3_000/2__000);    -- doubled in the denominator
println(0x_FF);           -- directly after the radix prefix
println(0x1_);            -- trailing in a hex literal
println(0x1__F);          -- doubled in a hex literal
