// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;
pragma abicoder v2;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

library Address {

  function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

interface IERC20 {
    function decimals() external view returns (uint8);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function totalSupply() external view returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract CommunityDAO {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    // Events
    event PublishTweet( uint amount, address caller, string content, uint tweetId );
    event ReservesUpdated( uint indexed totalReserves );
    event Active( bool isActive );
    event Vote( address caller, uint tweetId );


    address public immutable DAI;
    address public owner;
    bool public isActive;
    uint public totalReserves; // Reserves in seconds
    address[] public addressAlreadyVoted;
    mapping( address => bool ) public alreadyVoted;

    struct Tweet {
        uint _id;
        address _address;
        uint _amount;
        string _content;
        uint _timestamp;
        uint _votes;
    }
    Tweet[] public tweets;
    uint public nextTweetIn; // in timestamp
    uint id = 0;

    constructor ( address _DAI ) {
        owner = msg.sender;
        DAI = _DAI;
    }


    /**
        @notice add tweet into tweets list
        @param _amount uint
        @param _content string
     */
    function publishTweet( uint _amount, string memory _content ) external {
        require( isActive, "Not active" );
        require( IERC20( DAI ).balanceOf(msg.sender) >= _amount, "Not have sufficient DAI" );

        IERC20( DAI ).safeTransferFrom( msg.sender, address(this), _amount ); // Send transfer
        totalReserves = totalReserves.add( _amount );

        Tweet memory tweet = Tweet(id, msg.sender, _amount, _content, block.timestamp, 0);
        tweets.push(tweet);
        id = id + 1;

        emit ReservesUpdated( totalReserves );
        emit PublishTweet( _amount, msg.sender, _content, id );
    }


    /**
        @notice add vote inside tweet to be the next
        @param _tweetId uint
     */
    function vote( uint _tweetId ) external {
        require( isActive, "Not active" );
        require( !alreadyVoted[ msg.sender ] , "Caller already voted" );
        uint tweetIndex = getTweetIndex(_tweetId);

        tweets[tweetIndex]._votes = tweets[tweetIndex]._votes + 1;
        alreadyVoted[msg.sender] = true; // Add caller as voter
        addressAlreadyVoted.push(msg.sender);

        emit Vote( msg.sender, _tweetId );
    }


    /**
        @notice active or disable system
     */
    function toggleActive() external {
        require( msg.sender == owner, "Unauthorized" );
        isActive = !isActive;

        emit Active(isActive);
    }


    /**
        @notice check and return tweet index by tweet id
        @param _tweetId uint
        @return uint
     */
    function getTweetIndex( uint _tweetId ) internal view returns ( uint ) {
        for( uint i = 0; i < tweets.length; i++ ) {
            if( tweets[i]._id == _tweetId ) {
                return i;
            }
        }
        return 0;
    }


    /**
        @notice set the next tweet in timestamp
        @param _timestamp uint
     */
    function setNextTweet( uint _timestamp ) external {
        require( msg.sender == owner, "Unauthorized" );
        nextTweetIn = _timestamp;
         // Reset votes
        resetVotes();
        delete addressAlreadyVoted;
         // Reset tweets
        delete tweets;
    }


    /**
        @notice return all tweets
        @return Tweet[]
     */
    function getTweets() external view returns ( Tweet[] memory ) {
        return tweets;
    }


    /**
        @notice clean map and reset votes
     */
    function resetVotes() internal {
        for( uint i = 0; i < addressAlreadyVoted.length; i++ ) {
            address vot = addressAlreadyVoted[i];
            delete alreadyVoted[vot];
        }
    }
}