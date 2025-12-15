// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DecentralizedJobBoard
 * @dev A platform for posting and completing tasks.
 * 1. Employer posts a job and sends ETH to the contract.
 * 2. Worker accepts the job.
 * 3. Worker marks job as "Completed".
 * 4. Employer verifies and pays the worker.
 *
 * ZERO FEES. Easy to deploy (no constructor args).
 */
contract JobBoard {

    enum JobStatus { Open, InProgress, Completed, Paid }

    struct Job {
        uint256 id;
        address employer;
        address worker;
        string description;
        uint256 amount;
        JobStatus status;
    }

    Job[] public jobs;
    uint256 public jobCount;

    event JobPosted(uint256 indexed id, address indexed employer, uint256 amount);
    event JobTaken(uint256 indexed id, address indexed worker);
    event JobCompleted(uint256 indexed id);
    event WorkerPaid(uint256 indexed id, address indexed worker, uint256 amount);

    // No constructor arguments needed!
    constructor() {}

    /**
     * @dev Employer posts a new job. Payment is locked in the contract.
     */
    function postJob(string memory _description) public payable {
        require(msg.value > 0, "Job payment must be > 0");

        jobs.push(Job({
            id: jobCount,
            employer: msg.sender,
            worker: address(0), // No worker yet
            description: _description,
            amount: msg.value,
            status: JobStatus.Open
        }));

        emit JobPosted(jobCount, msg.sender, msg.value);
        jobCount++;
    }

    /**
     * @dev Worker accepts an open job.
     */
    function takeJob(uint256 _jobId) public {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Open, "Job is not open");
        require(msg.sender != job.employer, "Employer cannot take their own job");

        job.worker = msg.sender;
        job.status = JobStatus.InProgress;

        emit JobTaken(_jobId, msg.sender);
    }

    /**
     * @dev Worker signals they have finished the work.
     */
    function markJobComplete(uint256 _jobId) public {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.worker, "Only the worker can complete the job");
        require(job.status == JobStatus.InProgress, "Job is not in progress");

        job.status = JobStatus.Completed;
        emit JobCompleted(_jobId);
    }

    /**
     * @dev Employer approves the work and releases funds to worker.
     */
    function payWorker(uint256 _jobId) public {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.employer, "Only employer can release funds");
        require(job.status == JobStatus.Completed, "Job is not marked as complete yet");

        job.status = JobStatus.Paid;
        
        (bool success, ) = job.worker.call{value: job.amount}("");
        require(success, "Payment failed");

        emit WorkerPaid(_jobId, job.worker, job.amount);
    }

    // --- View Functions ---
    function getJobs() public view returns (Job[] memory) {
        return jobs;
    }
}