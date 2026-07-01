// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenGovernor
/// @notice Simple on-chain governance for token holders
contract TokenGovernor is Ownable {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
    }

    uint256 public proposalCount;
    uint256 public votingPeriod = 3 days;
    uint256 public quorum = 100_000 * 10 ** 18;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, address proposer, string description);
    event Voted(uint256 indexed id, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function propose(string calldata description) external returns (uint256) {
        uint256 id = ++proposalCount;
        proposals[id] = Proposal({
            id: id,
            proposer: msg.sender,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            executed: false,
            canceled: false
        });
        emit ProposalCreated(id, msg.sender, description);
        return id;
    }

    function vote(uint256 proposalId, bool support, uint256 weight) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp <= p.endTime, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }
        emit Voted(proposalId, msg.sender, support, weight);
    }

    function execute(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp > p.endTime, "Voting not ended");
        require(!p.executed, "Already executed");
        require(p.forVotes >= quorum, "Quorum not reached");
        require(p.forVotes > p.againstVotes, "Proposal rejected");
        p.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function setVotingPeriod(uint256 _period) external onlyOwner {
        votingPeriod = _period;
    }

    function setQuorum(uint256 _quorum) external onlyOwner {
        quorum = _quorum;
    }
}
