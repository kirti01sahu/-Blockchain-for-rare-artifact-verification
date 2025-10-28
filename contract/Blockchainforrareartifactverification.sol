
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RareArtifactVerification
 * @dev Smart contract for verifying and tracking rare artifacts on blockchain
 */
contract RareArtifactVerification {
    
    struct Artifact {
        uint256 id;
        string name;
        string description;
        string origin;
        uint256 yearOfCreation;
        address currentOwner;
        address verifier;
        uint256 verificationTimestamp;
        bool isVerified;
        string ipfsHash; // For storing images/documents
    }
    
    struct OwnershipHistory {
        address owner;
        uint256 timestamp;
        uint256 price;
    }
    
    mapping(uint256 => Artifact) public artifacts;
    mapping(uint256 => OwnershipHistory[]) public ownershipHistory;
    mapping(address => bool) public authorizedVerifiers;
    
    uint256 public artifactCount;
    address public admin;
    
    event ArtifactRegistered(uint256 indexed artifactId, string name, address indexed owner);
    event ArtifactVerified(uint256 indexed artifactId, address indexed verifier);
    event OwnershipTransferred(uint256 indexed artifactId, address indexed from, address indexed to, uint256 price);
    event VerifierAuthorized(address indexed verifier);
    event VerifierRevoked(address indexed verifier);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyVerifier() {
        require(authorizedVerifiers[msg.sender], "Only authorized verifiers can perform this action");
        _;
    }
    
    modifier onlyArtifactOwner(uint256 _artifactId) {
        require(artifacts[_artifactId].currentOwner == msg.sender, "Only artifact owner can perform this action");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        authorizedVerifiers[msg.sender] = true;
    }
    
    /**
     * @dev Register a new rare artifact on the blockchain
     * @param _name Name of the artifact
     * @param _description Detailed description
     * @param _origin Geographic or cultural origin
     * @param _yearOfCreation Year the artifact was created
     * @param _ipfsHash IPFS hash for artifact documentation/images
     */
    function registerArtifact(
        string memory _name,
        string memory _description,
        string memory _origin,
        uint256 _yearOfCreation,
        string memory _ipfsHash
    ) public returns (uint256) {
        artifactCount++;
        
        Artifact memory newArtifact = Artifact({
            id: artifactCount,
            name: _name,
            description: _description,
            origin: _origin,
            yearOfCreation: _yearOfCreation,
            currentOwner: msg.sender,
            verifier: address(0),
            verificationTimestamp: 0,
            isVerified: false,
            ipfsHash: _ipfsHash
        });
        
        artifacts[artifactCount] = newArtifact;
        
        // Record initial ownership
        ownershipHistory[artifactCount].push(OwnershipHistory({
            owner: msg.sender,
            timestamp: block.timestamp,
            price: 0
        }));
        
        emit ArtifactRegistered(artifactCount, _name, msg.sender);
        
        return artifactCount;
    }
    
    /**
     * @dev Verify an artifact's authenticity (only authorized verifiers)
     * @param _artifactId ID of the artifact to verify
     */
    function verifyArtifact(uint256 _artifactId) public onlyVerifier {
        require(_artifactId > 0 && _artifactId <= artifactCount, "Invalid artifact ID");
        require(!artifacts[_artifactId].isVerified, "Artifact already verified");
        
        artifacts[_artifactId].isVerified = true;
        artifacts[_artifactId].verifier = msg.sender;
        artifacts[_artifactId].verificationTimestamp = block.timestamp;
        
        emit ArtifactVerified(_artifactId, msg.sender);
    }
    
    /**
     * @dev Transfer ownership of an artifact
     * @param _artifactId ID of the artifact
     * @param _newOwner Address of the new owner
     * @param _price Transaction price in wei
     */
    function transferOwnership(
        uint256 _artifactId,
        address _newOwner,
        uint256 _price
    ) public onlyArtifactOwner(_artifactId) {
        require(_artifactId > 0 && _artifactId <= artifactCount, "Invalid artifact ID");
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");
        
        address previousOwner = artifacts[_artifactId].currentOwner;
        artifacts[_artifactId].currentOwner = _newOwner;
        
        // Record ownership change
        ownershipHistory[_artifactId].push(OwnershipHistory({
            owner: _newOwner,
            timestamp: block.timestamp,
            price: _price
        }));
        
        emit OwnershipTransferred(_artifactId, previousOwner, _newOwner, _price);
    }
    
    /**
     * @dev Authorize a new verifier (only admin)
     * @param _verifier Address of the verifier to authorize
     */
    function authorizeVerifier(address _verifier) public onlyAdmin {
        require(_verifier != address(0), "Invalid verifier address");
        require(!authorizedVerifiers[_verifier], "Verifier already authorized");
        
        authorizedVerifiers[_verifier] = true;
        emit VerifierAuthorized(_verifier);
    }
    
    /**
     * @dev Revoke verifier authorization (only admin)
     * @param _verifier Address of the verifier to revoke
     */
    function revokeVerifier(address _verifier) public onlyAdmin {
        require(authorizedVerifiers[_verifier], "Verifier not authorized");
        require(_verifier != admin, "Cannot revoke admin");
        
        authorizedVerifiers[_verifier] = false;
        emit VerifierRevoked(_verifier);
    }
    
    /**
     * @dev Get complete artifact information
     * @param _artifactId ID of the artifact
     */
    function getArtifact(uint256 _artifactId) public view returns (
        uint256 id,
        string memory name,
        string memory description,
        string memory origin,
        uint256 yearOfCreation,
        address currentOwner,
        address verifier,
        uint256 verificationTimestamp,
        bool isVerified,
        string memory ipfsHash
    ) {
        require(_artifactId > 0 && _artifactId <= artifactCount, "Invalid artifact ID");
        Artifact memory artifact = artifacts[_artifactId];
        
        return (
            artifact.id,
            artifact.name,
            artifact.description,
            artifact.origin,
            artifact.yearOfCreation,
            artifact.currentOwner,
            artifact.verifier,
            artifact.verificationTimestamp,
            artifact.isVerified,
            artifact.ipfsHash
        );
    }
    
    /**
     * @dev Get ownership history of an artifact
     * @param _artifactId ID of the artifact
     */
    function getOwnershipHistory(uint256 _artifactId) public view returns (OwnershipHistory[] memory) {
        require(_artifactId > 0 && _artifactId <= artifactCount, "Invalid artifact ID");
        return ownershipHistory[_artifactId];
    }
    
    /**
     * @dev Get total number of artifacts registered
     */
    function getTotalArtifacts() public view returns (uint256) {
        return artifactCount;
    }
}
