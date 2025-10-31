with System;
with Runtime_Support;
with Interrupts;
with neorv32.UART0; use neorv32.UART0;
with neorv32;
with Uart0;
with Interfaces;use Interfaces;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Characters.Handling; use Ada.Characters.Handling;
procedure Wishbone_Test is

   --Addresses used inside Wishbone peripheral
   LED_Address: aliased Interfaces.Unsigned_32;
   Button_Address: aliased Interfaces.Unsigned_32;

   for LED_Address'Address use System'To_Address(16#90000000#);
   --In LED_Address'Address, 'Address is an attribute. It is common to all objects
   --System'To_Address is equivalent to System.Storage_Elements.To_Address, but works in more general contexts
   --The above two lines are discussed more in https://learn.adacore.com/courses/intro-to-embedded-sys-prog/chapters/interacting_with_devices.html
   --for .. use .. is complex. I had to use Claude to find what syntax could be used to assign this address to the variable
   --for .. use .. is normally used for representation clauses (enums)
   for Button_Address'Address use System'To_Address(16#90000004#);

   --16#<number>#
   --The above means that the number between the two # is a hexadecimal number 
                                   
   pragma Volatile(LED_Address);   --Volatile means value may change anytime
                                   --pragma is a directive that enforce this volatile nature (requred syntax)
   pragma Volatile(Button_Address);

   --Write value to LED peripheral
   --Procedure because this function returns nothing
   procedure Led_Write (Value:Interfaces.Unsigned_8) is
   begin
      LED_Address:= Interfaces.Unsigned_32(Value); --Convert int8 parameter to int32 because the LED_Address points to a memory location that stores int32 numbers
   end Led_Write;

   --Read button state (lower 3 bits)
   --function because this function returns an in8 number
   function Button_Read return Interfaces.Unsigned_8 is
      Raw_Value:Interfaces.Unsigned_32:=Button_Address;
   begin
      return Interfaces.Unsigned_8(Raw_Value and 16#7#);--16#7# = 0x7
   end Button_Read;

   --Delay to allow the peripheral to complete computations
   --This mechanism should be replaced with a better logic. Maybe a program complete signal in the peripheral?
   procedure NEORV32Delay(Count:Interfaces.Unsigned_32) is
      Dummy:Interfaces.Unsigned_32 := 0;
      pragma Volatile (Dummy);
   begin
      for I in 1 .. Integer (Count) loop
         Dummy := Dummy + 1;
      end loop;
   end NEORV32Delay;

   Button_State : Interfaces.Unsigned_8 := 0;

begin
   --Initialize UART
   Uart0.Init(19200);
   Put_Line("<<< NEORV32 XBUS Peripheral Test >>>");
   Put_Line("LED Address:    0x90000000");
   Put_Line("Button Address: 0x90000004\n");

   --Test 1:Binary counter on LEDs
   Put_Line ("Test 1: Binary counter on LEDs");
   for I in 0..255 loop
      Led_Write(Interfaces.Unsigned_8(I));
      NEORV32Delay(500000);
   end loop;

   -- Test 2: Button to LED mapping
   Put_Line ("Test 2: Press buttons - state shown on LEDs");
   Put_Line ("Running continuously...");
   loop
      Button_State := Button_Read;
      Led_Write (Button_State);
      NEORV32Delay (50000);
   end loop;

end Wishbone_Test;
