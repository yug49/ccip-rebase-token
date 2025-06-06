//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Yug Agarwal
 * @dev A simple ERC20 token extended as a rebase token.
 * @dev interest rate can only decrease and that too with by the owner of the contract
 *                                                                         
                         .            .                                   .#                        
                       +#####+---+###+#############+-                  -+###.                       
                       +###+++####+##-+++++##+++##++####+-.         -+###+++                        
                       +#########.-#+--+####++###- -########+---+++#####+++                         
                       +#######+#+++--+####+-..-+-.###+++########+-++###++.                         
                      +######.     +#-#####+-.-------+############+++####-                          
                     +####++...     ########-++-        +##########++++++.                          
                    -#######-+.    .########+++          -++######+++-                               
                    #++########--+-+####++++-- . ..    .-#++--+##+####.                              
                   -+++++++++#####---###---.----###+-+########..-+#++##-                            
                   ++###+++++#####-..---.. .+##++++#++#++-+--.   .-++++#                             
                  .###+.  .+#+-+###+ ..    +##+##+#++----...---.  .-+--+.                            
                  ###+---------+####+   -####+-.......    ...--++.  .---.                           
                 -#++++-----#######+-  .-+###+.... .....      .-+##-.  .                            
                 ##+++###++######++-.   .--+---++---........  ...---.  .                            
                -####+-+#++###++-.        .--.--...-----.......--..... .                            
                +######+++###+--..---.....  ...---------------.. .. .  .                            
               .-#########+#+++--++--------......----++--.--.  .--+---.                             
                -+++########++--++++----------------------.--+++--+++--                             
           .######-.-++++###+----------------------..---++--++-+++---..                             
           -##########-------+-----------------------+-++-++----..----+----+#####++--..             
           -#############+..  ..--..----------.....-+++++++++++++++++##################+.           
           --+++++#########+-   . ....  ....... -+++++++++++++++++++############-.----+##-          
           -----....-+#######+-             .. -+++++++++++++++++++++##+######+.       +++.         
           --------.....---+#####+--......----.+++++++++++++++++++++##+-+++##+.        -++-         
           -------...   .--++++++---.....-----.+++++++++++++++++++++++. -+++##-        .---         
           #################+--.....-------.  .+++++++++++++++++++++-       -+-.       .---         
           +#########++++-.. .......-+--..--++-++++++++++++++++++++-         .-... ....----         
           -#####++---..   .--       -+++-.  ..+++++++++++++++++++--        .-+-......-+---         
           +####+---...    -+#-   .  --++++-. .+++++++++++++++++++---        --        -+--         
           ++++++++++--....-++.--++--.--+++++-.+++++++++++++++++++---. .......         ----         
          .--++#########++-.--.+++++--++++###+-++++++++++++++++++++----   .-++-        ----         
           .-+#############+-.++#+-+-++#######-++++++++++++++++++++----   -++++-      ..---         
          .---+############+.+###++--++#####++-+++++++++++++++++++++-------++++-........-+-         
           --+-+##########-+######+++++-++++++-++++++++++++++++++++++-----.----.......---+-         
          .--+---#######..+#######+++++++--+++-+++++++++++++++++++++++-----------------+++-         
          .++--..-+##-.-########+++++---++ .+-.+++++++++++++++++++++++++++++++++++---+++++-         
          -+++. ..-..-+#########++-++--..--....+++++++++++++++++++++++++++++++++++++++++++-         
          -++-......-+++############++++----- .+++++++++++++++++++++++++++++++++++++++++++-         
          +##-.....---+#######+####+####+--++-.+++++++++++++++++++++++++++++++++++++++++++-         
         .#+++-...-++######++-+-----..----++##-+++++++++++++++++++++++++++++++++++++++++++-         
         .+++--------+##----+------+-..----+++-+++++++++++++++++++++++++++++++++++++++++++-         
          ----.-----+++-+-...------++-----...--+++++++++++++++++++++++++++++++++++++++++++-         
         .-..-.--.----..--.... ....++--.  ....-+++++++++++++++++++++++++++++++++++++++++++-         
          -----------.---..--..   ..+.  . ... .+++++++++++++++++++++++++++++++++++++++++++-         
        .+#+#+---####+-.    .....--...   .    .+++++++++++++++++++++++++++++++++++++++++++-         
        -+++++#++++++++.    ..-...--.. ..     .+++++++++++++++++++++++++++++++++++++++++++-         
        ++++++-------++--   . ....--.. . . .. .+++++++++++++++++++++++++-+----------...             
        -++++--++++.------......-- ...  ..  . .---------------...                                   
        -++-+####+++---..-.........                                                                  
          .....                                                                                      
 */
contract RebaseToken is ERC20{
    error RebaseToken__InterestRateCannotIncrease(uint256 currentRate, uint256 newRate);

    uint256 private constant PERCISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e18;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 indexed newRate);

    constructor() ERC20("RebaseToken", "RBT"){}

    /**
     * @dev Sets a new interest rate for the token.
     * @param _newRate The new interest rate to be set, must be less than or equal to the current rate.
     */
    function setInterestRate(uint256 _newRate) external {
        // Set the interest rate
        if(_newRate < s_interestRate) {
            revert RebaseToken__InterestRateCannotIncrease(s_interestRate, _newRate);
        }
        s_interestRate = _newRate;
        emit InterestRateSet(_newRate);
    }

    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current priciple balance -> the number of tokens actually minted to the user
        // multiply the principle balance by the interest rate
        return (super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdated(_user)) / PERCISION_FACTOR;
    }

    function _calculateUserAccumulatedInterestSinceLastUpdated(address _user) internal view returns (uint256) {
        // we need to calculate the interest rate since the last time the user was updated
        // this is going to be linear growth with time
        // deposite : 10 tokens
        // interest rate 0.5 tokens per second
        // time elapsed is 2 seconds
        // 10 + (10 * 0.5 * 2) = 20 tokens

        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        uint256 linearInterest = PERCISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);

        return linearInterest;
    }

    function _mintAccruedInterest(address _user) internal {
        // find their current balance of rebase tokens that have been minted to them
        // calculate the balance including any interest -> balance
        // calculate the number of tokens need to be minted to the user -> (2) - (1)
        // call _mint to mint the balance to the user
        //set the user last minted timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}