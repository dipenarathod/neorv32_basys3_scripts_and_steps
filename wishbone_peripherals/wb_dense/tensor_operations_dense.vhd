Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;

Package tensor_operations_dense Is

	Constant OP_DENSE : Std_ulogic_vector(4 Downto 0) := "00111"; --Dense layer opcode (5-bit)

	--Single MAC (multiply-accumulate)
	--Not used
	Function dense_mac(
		accumulator : signed(23 Downto 0);
		input_val   : signed(7 Downto 0);
		weight_val  : signed(7 Downto 0)
	)Return signed;

	--4-lane MAC
	--Processes up to 4 consecutive input, weight pairs
	--valid_lanes inform how many lanes are to be processed
	Function dense_mac4(
		accumulator : signed(23 Downto 0);
		input_word  : Std_ulogic_vector(31 Downto 0);
		weight_word : Std_ulogic_vector(31 Downto 0);
		valid_lanes : Natural Range 1 To 4
	) Return signed;

	--Add bias to accumulated result and saturate to Q0.7 range
	Function dense_add_bias_and_saturate(
		accumulator : signed(23 Downto 0);
		bias        : signed(7 Downto 0)
	) Return signed;

	--Extract byte from packed word (0 to 3 index)
	Function extract_byte_from_word(
		word       : Std_ulogic_vector(31 Downto 0);
		byte_index : Natural Range 0 To 3
	) Return signed;

End Package tensor_operations_dense;

Package Body tensor_operations_dense Is

	--Single MAC (multiply-accumulate)
	--MAC operation: accumulator += input * weight
	--Not used
	Function dense_mac(
		accumulator : signed(23 Downto 0);
		input_val   : signed(7 Downto 0);
		weight_val  : signed(7 Downto 0)
	) Return signed Is
		Variable product : signed(15 Downto 0);
		Variable extended_product : signed(23 Downto 0);
		Variable result : signed(23 Downto 0);
	Begin

		product := input_val * weight_val; --Product is 16-bit
		--Extend to 24-bit for accumulation
		extended_product := resize(product, 24);
		--Accumulate
		result := accumulator + extended_product;
		Return result;
	End Function;

	--4-lane MAC
	--Processes up to 4 consecutive input, weight pairs
	--valid_lanes inform how many lanes are to be processed
	Function dense_mac4(
		accumulator : signed(23 Downto 0);
		input_word  : Std_ulogic_vector(31 Downto 0);
		weight_word : Std_ulogic_vector(31 Downto 0);
		valid_lanes : Natural Range 1 To 4
	) Return signed Is
		Variable a0, a1, a2, a3 : signed(7 Downto 0);
		Variable w0, w1, w2, w3 : signed(7 Downto 0);
		Variable p0, p1, p2, p3 : signed(15 Downto 0);
		Variable sum_products : signed(23 Downto 0);
		Variable result : signed(23 Downto 0);
	Begin
		--Extract lane bytes
		a0 := extract_byte_from_word(input_word, 0);
		a1 := extract_byte_from_word(input_word, 1);
		a2 := extract_byte_from_word(input_word, 2);
		a3 := extract_byte_from_word(input_word, 3);
		w0 := extract_byte_from_word(weight_word, 0);
		w1 := extract_byte_from_word(weight_word, 1);
		w2 := extract_byte_from_word(weight_word, 2);
		w3 := extract_byte_from_word(weight_word, 3);

		--Multiply only the required lanes
		p0 := (Others => '0');
		p1 := (Others => '0');
		p2 := (Others => '0');
		p3 := (Others => '0');
		If (valid_lanes >= 1) Then
			p0 := a0 * w0;
		End If;

		If (valid_lanes >= 2) Then
			p1 := a1 * w1;
		End If;

		If (valid_lanes >= 3) Then
			p2 := a2 * w2;
		End If;

		If (valid_lanes >= 4) Then
			p3 := a3 * w3;
		End If;

		--Sum products in 24-bit precision
		sum_products := resize(p0, 24) + resize(p1, 24) + resize(p2, 24) + resize(p3, 24);

		--Accumulate
		result := accumulator + sum_products;
		Return result;
	End Function;

	--Add bias and convert back to Q0.7 with saturation
	--Accumulator is sum of Q0.14 products, so we need to shift right by 7 bits
	--to convert back to Q0.7, then add bias
	Function dense_add_bias_and_saturate(
		accumulator : signed(23 Downto 0);
		bias        : signed(7 Downto 0)
	) Return signed Is
		Variable scaled : signed(23 Downto 0);
		Variable with_bias : signed(23 Downto 0);
		Variable result : signed(7 Downto 0);
	Begin
		--Scale down from Q0.14 to Q0.7 by shifting right 7 bits
		--This effectively divides by 128
		scaled := shift_right(accumulator, 7);

		--Add bias (extend bias to 24-bit first)
		with_bias := scaled + resize(bias, 24);
		--Saturate to Q0.7 range [-128, 127]
		If (with_bias > to_signed(127, 24)) Then
			result := to_signed(127, 8);
		Elsif (with_bias < to_signed(-128, 24)) Then
			result := to_signed(-128, 8);
		Else
			result := resize(with_bias, 8);
		End If;
		Return result;
	End Function;

	--Extract signed byte from packed 32-bit word
	Function extract_byte_from_word(
		word       : Std_ulogic_vector(31 Downto 0);
		byte_index : Natural Range 0 To 3
	) Return signed Is
		Variable byte_val : Std_ulogic_vector(7 Downto 0);
	Begin
		Case byte_index Is
			When 0 => byte_val := word(7 Downto 0);
			When 1 => byte_val := word(15 Downto 8);
			When 2 => byte_val := word(23 Downto 16);
			When 3 => byte_val := word(31 Downto 24);
		End Case;
		Return signed(byte_val);
	End Function;

End Package Body tensor_operations_dense;