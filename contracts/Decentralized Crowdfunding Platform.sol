// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Project {
    // Project structure
    struct CrowdfundingProject {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isCompleted;
        bool fundsWithdrawn;
    }
    
    // Contribution structure
    struct Contribution {
        address contributor;
        uint256 amount;
    }
    
    // State variables
    mapping(uint256 => CrowdfundingProject) public projects;
    mapping(uint256 => Contribution[]) public projectContributions;
    mapping(uint256 => mapping(address => uint256)) public contributorAmounts;
    
    uint256 public projectCounter;
    
    // Events
    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed projectId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundIssued(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );
    
    // Modifiers
    modifier onlyCreator(uint256 _projectId) {
        require(
            msg.sender == projects[_projectId].creator,
            "Only project creator can call this function"
        );
        _;
    }
    
    modifier projectExists(uint256 _projectId) {
        require(_projectId < projectCounter, "Project does not exist");
        _;
    }
    
    modifier deadlineNotPassed(uint256 _projectId) {
        require(
            block.timestamp < projects[_projectId].deadline,
            "Project deadline has passed"
        );
        _;
    }
    
    // Core Function 1: Create a new crowdfunding project
    function createProject(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        projects[projectCounter] = CrowdfundingProject({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            isCompleted: false,
            fundsWithdrawn: false
        });
        
        emit ProjectCreated(
            projectCounter,
            msg.sender,
            _title,
            _goalAmount,
            deadline
        );
        
        projectCounter++;
    }
    
    // Core Function 2: Contribute to a project
    function contributeToProject(uint256 _projectId)
        external
        payable
        projectExists(_projectId)
        deadlineNotPassed(_projectId)
    {
        require(msg.value > 0, "Contribution must be greater than 0");
        require(
            !projects[_projectId].isCompleted,
            "Project is already completed"
        );
        
        CrowdfundingProject storage project = projects[_projectId];
        project.raisedAmount += msg.value;
        
        // Record contribution
        projectContributions[_projectId].push(
            Contribution({
                contributor: msg.sender,
                amount: msg.value
            })
        );
        
        contributorAmounts[_projectId][msg.sender] += msg.value;
        
        // Check if goal is reached
        if (project.raisedAmount >= project.goalAmount) {
            project.isCompleted = true;
        }
        
        emit ContributionMade(_projectId, msg.sender, msg.value);
    }
    
    // Core Function 3: Withdraw funds (if goal reached) or get refund (if goal not reached after deadline)
    function withdrawFundsOrRefund(uint256 _projectId)
        external
        projectExists(_projectId)
    {
        CrowdfundingProject storage project = projects[_projectId];
        
        // Case 1: Creator withdrawing funds after successful funding
        if (
            msg.sender == project.creator &&
            project.isCompleted &&
            !project.fundsWithdrawn
        ) {
            project.fundsWithdrawn = true;
            uint256 amount = project.raisedAmount;
            project.creator.transfer(amount);
            
            emit FundsWithdrawn(_projectId, msg.sender, amount);
        }
        // Case 2: Contributor getting refund after failed funding
        else if (
            block.timestamp >= project.deadline &&
            !project.isCompleted &&
            contributorAmounts[_projectId][msg.sender] > 0
        ) {
            uint256 refundAmount = contributorAmounts[_projectId][msg.sender];
            contributorAmounts[_projectId][msg.sender] = 0;
            
            payable(msg.sender).transfer(refundAmount);
            
            emit RefundIssued(_projectId, msg.sender, refundAmount);
        } else {
            revert("No funds available for withdrawal or refund");
        }
    }
    
    // Helper Functions
    function getProject(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isCompleted,
            bool fundsWithdrawn
        )
    {
        CrowdfundingProject storage project = projects[_projectId];
        return (
            project.creator,
            project.title,
            project.description,
            project.goalAmount,
            project.raisedAmount,
            project.deadline,
            project.isCompleted,
            project.fundsWithdrawn
        );
    }
    
    function getProjectContributions(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (Contribution[] memory)
    {
        return projectContributions[_projectId];
    }
    
    function getContributorAmount(uint256 _projectId, address _contributor)
        external
        view
        projectExists(_projectId)
        returns (uint256)
    {
        return contributorAmounts[_projectId][_contributor];
    }
    
    function getTotalProjects() external view returns (uint256) {
        return projectCounter;
    }
}
