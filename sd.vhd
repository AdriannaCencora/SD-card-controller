----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:28:48 05/02/2020 
-- Design Name: 
-- Module Name:    sd_card_controller - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
--use ieee.std_logic_signed.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;





use work.enum_types.all;

entity sd_card_controller is
	port (
		
		clk_i   : in std_logic;					 -- Master clock
		reset_i : in std_logic;  -- active-high, synchronous  reset
		data_i  : in  std_logic_vector(7 downto 0);		-- Data to write to block
		data_o : out std_logic_vector(47 downto 0);
		
		miso_i  : in  std_logic;  -- Serial data input from SD card
		cs_o   : out std_logic;	-- Active-low chip-select
		mosi_o : out std_logic;	-- Serial data output to SD card
		sclk_o : out std_logic;	-- Serial clock to SD card
		
		command   : out  std_logic_vector(47 downto 0)
		--fsm_state : out FSM_state_type
		);
end sd_card_controller;

architecture Behavioral of sd_card_controller is

		signal state_s		: FSM_state_type := INIT;	
		signal return_state_s : FSM_state_type;

begin

	process(clk_i)
		variable bitCnt_v : natural;
		variable tx_v : std_logic_vector(47 downto 0);
		variable rx_v : std_logic_vector(47 downto 0); 
		
		subtype  Cmd_t is std_logic_vector(7 downto 0);
		constant CMD0_C          : Cmd_t := std_logic_vector(to_unsigned(16#40# + 0, Cmd_t'length));
		constant CMD8_C          : Cmd_t := std_logic_vector(to_unsigned(16#40# + 8, Cmd_t'length));
		constant CMD55_C         : Cmd_t := std_logic_vector(to_unsigned(16#40# + 55, Cmd_t'length));
		constant ACMD41_C        : Cmd_t := std_logic_vector(to_unsigned(16#40# + 41, Cmd_t'length));

	begin
		if rising_edge(clk_i) then

			if reset_i = '1' then			
				state_s  <= INIT;		

			else
				case state_s is

					when INIT =>
						state_s          <= SEND_CMD0; 
						
					when SEND_CMD0 =>			
						cs_o			 	  <= '0';		
						tx_v             := CMD0_C & x"00000000" & x"95"; 
						bitCnt_v         := tx_v'length;  
						state_s          <= TX_BITS;
						return_state_s   <= GET_CMD0_RESPONSE;

					when GET_CMD0_RESPONSE =>  
						if rx_v = x"00" then
							state_s <= SEND_CMD8;
						else
							state_s <= SEND_CMD0; 
						end if;
						
					when SEND_CMD8 => 
						cs_o   	 	<= '0';
						tx_v  	:= CMD8_C & x"00000000" & x"95";
						bitCnt_v 	:= tx_v'length; 
						state_s  	<= TX_BITS; 
					   return_state_s   <= GET_CMD8_RESPONSE; 
					
					when GET_CMD8_RESPONSE =>
						state_s <= SEND_CMD55;
					
					
					when SEND_CMD55 => 
						cs_o   	 	<= '0'; 
						tx_v  	:= CMD55_C & x"00000000" & x"95";
						bitCnt_v 	:= tx_v'length;  
						state_s  	<= TX_BITS; 
					   return_state_s   <= SEND_ACMD41; 
					
					when SEND_ACMD41 => 
						cs_o   	 	<= '0';
						tx_v  	:= ACMD41_C & x"00000000" & x"95";
						bitCnt_v 	:= tx_v'length; 
						state_s  	<= TX_BITS;
					   return_state_s   <= GET_ACMD41_RESPONSE;
					
					when GET_ACMD41_RESPONSE =>
	  			     if rx_v = x"11" then
							state_s <= SEND_CMD55;
						elsif rx_v = x"00" then
							null;  -- not implemented yet
						end if;
							
					when TX_BITS =>  
							if bitCnt_v /= 0 then  
								mosi_o   <= tx_v(tx_v'high);
								tx_v     := tx_v(tx_v'high-1 downto 0) & '0';
								bitCnt_v := bitCnt_v - 1;
							else
								mosi_o    <= '0';
								state_s   <= RX_BITS;
								bitCnt_v   := rx_v'length;
							end if;
							
					when RX_BITS =>
						rx_v := rx_v(rx_v'high-1 downto 0) & miso_i;
						if bitCnt_v /= 0 then
							bitCnt_v := bitCnt_v - 1;
						else
							data_o   <= rx_v; 
							state_s <= return_state_s;
						end if;
						
							
					when others =>
						state_s <= INIT;

				end case;
			end if;		
		end if;			
		command <= tx_v;
	end process;

	--fsm_state <= state_s;
	
	end architecture;

