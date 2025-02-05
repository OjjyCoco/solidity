// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable{

    // L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    // Ou on passe la whiteList directement dans le constructor ?
    mapping (address => bool) public whiteList;
    struct Voter {
        address voterAddress;
        bool isRegistered; // whiteListed = isRegistered ?
        bool hasVoted;
        uint votedProposalId;
    }
    // Voter[] voters;
    mapping (address => Voter) public voters; 
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
                        VotesTallied,
                        EndOfSession }
                        // ajouter un dernier status EndSession qui permet aux utilisateurs de getWinningProposal retourner le winningProposalId par défaut qui est 0
    WorkflowStatus public currentStatus;
    //currentStatus = WorkflowStatus.RegisteringVoters; // à check mais pas besoin normalement
    uint winningProposalId;

    // event declaration
    event VoterRegistered(address _address);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // pour initialiser le contrat avec le deployeur comme premier membre whitelisté:
    constructor() Ownable(msg.sender) {
        whiteList[msg.sender] = true;
        // il faut aussi RegisterVoter(msg.sender) ici
        emit VoterRegistered(msg.sender);
    }

    modifier onlyWhitelisted(){
        require(whiteList[msg.sender] == true, "Not whitelisted");
        _;
    }

    // Allow admin to add whitelisted voters
    function RegisterVoter(address _address) public onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters, "Voter registration is not active");
        require(!whiteList[_address], "Voter already registered");
        whiteList[_address] = true;
        // add Voter
        voters[_address] = Voter({
            voterAddress: _address,
            isRegistered: true,
            hasVoted: false,
            votedProposalId: 0   // doit-on obligatoirement mettre quelque chose ? ou égal 0 par default
        });
        emit VoterRegistered(_address);
    }

    // L'administrateur du vote commence la session d'enregistrement de la proposition.
    // function NextWorkflowStatus
    // iterates in WorkflowStatus
    function NextWorkflowStatus() public onlyOwner {
        require(uint(currentStatus) < uint(WorkflowStatus.VotesTallied), "Workflow already finished");
        WorkflowStatus previousStatus = currentStatus;
        currentStatus = WorkflowStatus(uint(currentStatus) + 1); // à verif si ça marche
        emit WorkflowStatusChange(previousStatus, currentStatus);
    }


    // Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
    // function RegisterProposal
    // if WorkflowStatus is ProposalsRegistrationStarted and if whitelisted then add proposal to array
    // on considère qu'un élécteur peut proposer plusieurs fois
    function RegisterProposal(string memory _description) public onlyWhitelisted {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration is not active");
        proposalsList.push(Proposal({
            proposalId: proposalsList.length, // juste ? .length donne avant ou après le push ?
            description: _description,
            voteCount: 0
        }));
        emit ProposalRegistered(proposalsList.length - 1); // Make sure good index
    }

    //L'administrateur de vote met fin à la session d'enregistrement des propositions.
    // activate function NextWorkflowStatus

    // L'administrateur du vote commence la session de vote.
    // activate function NextWorkflowStatus

    // Les électeurs inscrits votent pour leur proposition préférée.
    // if WorkflowStatus is VotingSessionStarted and if whiteListed and Voter.hasVoted = False then add +1 to ProposalChosen
    // function vote
    function vote(uint _voterProposalId) public onlyWhitelisted {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Voting session is not active");
        require(!voters[msg.sender].hasVoted, "You have already voted");
        require(_voterProposalId < proposalsList.length, "Invalid proposal");

        //màj du Voter dans le mapping
        voters[msg.sender].votedProposalId = _voterProposalId;
        voters[msg.sender].hasVoted = true;

        proposalsList[_voterProposalId].voteCount += 1;
        emit Voted(msg.sender, _voterProposalId);
    }

    // L'administrateur du vote met fin à la session de vote.
    // activate function NextWorkflowStatus

    // L'administrateur du vote comptabilise les votes.
    // activate function NextWorkflowStatus
    // function countVote
    // iterate on proposalsList and upgrade the proposal with the more votes to winningProposalId
    // What if equality ?
    function voteCount() public onlyOwner {
        require(currentStatus == WorkflowStatus.VotesTallied, "The vote current status is not to tally");
        uint winningVoteCount = 0;
        for (uint i = 0; i < proposalsList.length; i++) {
            if (proposalsList[i].voteCount > winningVoteCount) {
                // Pour l'instant c'est la première proposal submitted qui l'emporte
                winningVoteCount = proposalsList[i].voteCount;
                winningProposalId = i;
            }
        }
        // Pas sûr de pouvoir la mettre ici alors qu'elle est en onlyOnwer (quoique voteCount l'est aussi)
        NextWorkflowStatus();
    }

    // Tout le monde peut vérifier les derniers détails de la proposition gagnante.
    // function getWinningProposal
    // view func to show winning proposal caracteristics
    function getWinningProposal() public view returns(Proposal memory){
        // attendre le status EndOfSession afin qu'aucun utilisateur ne puisse get default winningProposalId et faire croire que le résultat est le proposal id 0
        require(currentStatus == WorkflowStatus.EndOfSession, "Votes are not tallied yet");
        return proposalsList[winningProposalId];
    }

    // Le vote n'est pas secret pour les utilisateurs ajoutés à la Whitelist
    // Chaque électeur peut voir les votes des autres
    // getter functions to get infos on voters by addresses
    //function getVoter(address _address) public view onlyWhitelisted returns(Voter memory){
    //    // require pas indispensable on peut consulter même si le vote n'a pas encore été fait
    //    return voters[_address];
    //}

}