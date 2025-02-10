// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable{

    mapping (address => bool) public whiteList;
    struct Voter {
        address voterAddress;
        bool isRegistered; // en considérant que whiteListed = isRegistered
        bool hasVoted;
        uint votedProposalId;
    }
    mapping (address => Voter) voters;
    struct Proposal {
        uint proposalId;
        string description;
        uint voteCount;
    }
    Proposal[] public proposalsList;
    enum WorkflowStatus { RegisteringVoters,
                        ProposalsRegistrationStarted,
                        ProposalRegistrationEnded,
                        VotingSessionStarted,
                        VotingSessionEnded,
                        VotesTallied }
    WorkflowStatus public currentStatus;
    uint winningProposalId;

    // event declaration
    event VoterRegistered(address _address);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // error declaration
    error InvalidWorkflowStatus();
    error WhitelistError();

    // pour initialiser le contrat avec le deployeur / admin comme premier membre whitelisté:
    constructor() Ownable(msg.sender) {
        whiteList[msg.sender] = true;
        // en considérant que l'admin peut voter
        voters[msg.sender] = Voter({voterAddress: msg.sender, isRegistered: true, hasVoted: false, votedProposalId:0});
        emit VoterRegistered(msg.sender);
    }

    modifier onlyWhitelisted(){
        require(whiteList[msg.sender] == true, WhitelistError());
        _;
    }

    // L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function RegisterVoter(address _address) public onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, InvalidWorkflowStatus());
        require(!whiteList[_address], WhitelistError());
        whiteList[_address] = true;
        voters[_address] = Voter({
            voterAddress: _address,
            isRegistered: true,
            hasVoted: false,
            votedProposalId: 0 // Malheureusement 0 par défaut... on pourra enregistrer les ProposalsID à partir de 1 si on veut bannir l'ID 0 ?
        });
        emit VoterRegistered(_address);
    }

    // L'administrateur du vote commence la session d'enregistrement de la proposition.
    function NextWorkflowStatus() public onlyOwner {
        require(uint(currentStatus) < uint(WorkflowStatus.VotesTallied), "Workflow already finished");
        WorkflowStatus previousStatus = currentStatus;
        currentStatus = WorkflowStatus(uint(currentStatus) + 1);
        emit WorkflowStatusChange(previousStatus, currentStatus);
    }

    // Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
    function RegisterProposal(string memory _description) public onlyWhitelisted {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, InvalidWorkflowStatus());
        proposalsList.push(Proposal({
            proposalId: proposalsList.length, // faire + 1 pour "bannir" proposalId 0
            description: _description,
            voteCount: 0
        }));
        emit ProposalRegistered(proposalsList.length - 1);
    }

    // Les électeurs inscrits votent pour leur proposition préférée.
    function vote(uint _voterProposalId) public onlyWhitelisted {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, InvalidWorkflowStatus());
        require(!voters[msg.sender].hasVoted, "You have already voted");
        require(_voterProposalId < proposalsList.length, "Invalid proposal");
        // require _voterProposalId > 0 ? si on veut bannir proposalId 0

        voters[msg.sender].votedProposalId = _voterProposalId;
        voters[msg.sender].hasVoted = true;

        proposalsList[_voterProposalId].voteCount += 1;
        emit Voted(msg.sender, _voterProposalId);
    }


    // L'administrateur du vote comptabilise les votes.
    function voteCount() public onlyOwner {
        require(currentStatus == WorkflowStatus.VotingSessionEnded, InvalidWorkflowStatus());
        uint winningVoteCount = 0;
        for (uint i = 0; i < proposalsList.length; i++) {
            if (proposalsList[i].voteCount > winningVoteCount) {
                // What if equality ?
                // Pour l'instant c'est la première proposal submitted qui l'emporte en cas d'égalité (Pour suciter la rapidité de soumission des propositions ;-)
                winningVoteCount = proposalsList[i].voteCount;
                winningProposalId = i;
            }
        }
        NextWorkflowStatus();
    }

    // Tout le monde peut vérifier les derniers détails de la proposition gagnante.
    function getWinningProposal() public view returns(Proposal memory){
        require(currentStatus == WorkflowStatus.VotesTallied, InvalidWorkflowStatus());
        return proposalsList[winningProposalId];
    }

    // Le vote n'est pas secret pour les utilisateurs ajoutés à la Whitelist
    // Chaque électeur peut voir les votes des autres
    function getVoter(address _address) public view onlyWhitelisted returns(Voter memory){
        // require pas indispensable on peut consulter même si le vote n'a pas encore été fait
        return voters[_address];
    }

}