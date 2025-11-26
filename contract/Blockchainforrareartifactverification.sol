// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RareArtifactVerification
 * @dev Smart contract for verifying and tracking rare artifacts on blockchain
 * @notice Optimized for gas efficiency and enhanced readability
 */
contract RareArtifactVerification {
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /// @notice Admin address with special privileges
    address public immutable admin;
    
    /// @notice Total number of registered artifacts
    uint256 public artifactCount;
    
    /// @notice Mapping of artifact ID to artifact data
    mapping(uint256 => Artifact) public artifacts;
    
    /// @notice Mapping of artifact ID to its ownership history
    mapping(uint256 => OwnershipHistory[]) public ownershipHistory;
    
    /// @notice Mapping of addresses authorized to verify artifacts
    mapping(address => bool) public authorizedVerifiers;
    
    // ============================================
    // STRUCTS
    // ============================================
    
    /// @notice Artifact data structure
    struct Artifact {
        string name;
        string description;
        string origin;
        string ipfsHash;
        address currentOwner;
        address verifier;
        uint96 yearOfCreation;      // uint96 saves gas vs uint256
        uint40 verificationTimestamp; // uint40 is sufficient for timestamps
        bool isVerified;
    }
    
    /// @notice Ownership transfer record
    struct OwnershipHistory {
        address owner;
        uint40 timestamp;  // uint40 saves gas vs uint256
        uint216 price;     // uint216 allows large values while saving gas
    }
    
    // ============================================
    // EVENTS
    // ============================================
    
    event ArtifactRegistered(
        uint256 indexed artifactId, 
        string name, 
        address indexed owner
    );
    
    event ArtifactVerified(
        uint256 indexed artifactId, 
        address indexed verifier
    );
    
    event OwnershipTransferred(
        uint256 indexed artifactId, 
        address indexed from, 
        address indexed to, 
        uint256 price
    );
    
    event VerifierAuthorized(address indexed verifier);
    event VerifierRevoked(address indexed verifier);
    
    // ============================================
    // ERRORS (Gas efficient alternative to require strings)
    // ============================================
    
    error OnlyAdmin();
    error OnlyVerifier();
    error OnlyArtifactOwner();
    error InvalidArtifactId();
    error AlreadyVerified();
    error InvalidAddress();
    error CannotTransferToSelf();
    error VerifierAlreadyAuthorized();
    error VerifierNotAuthorized();
    error CannotRevokeAdmin();
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }
    
    modifier onlyVerifier() {
        if (!authorizedVerifiers[msg.sender]) revert OnlyVerifier();
        _;
    }
    
    modifier onlyArtifactOwner(uint256 _artifactId) {
        if (artifacts[_artifactId].currentOwner != msg.sender) revert OnlyArtifactOwner();
        _;
    }
    
    modifier validArtifactId(uint256 _artifactId) {
        if (_artifactId == 0 || _artifactId > artifactCount) revert InvalidArtifactId();
        _;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        admin = msg.sender;
        authorizedVerifiers[msg.sender] = true;
    }
    
    // ============================================
    // EXTERNAL FUNCTIONS
    // ============================================
    
    /**
     * @dev Register a new rare artifact on the blockchain
     * @param _name Name of the artifact
     * @param _description Detailed description
     * @param _origin Geographic or cultural origin
     * @param _yearOfCreation Year the artifact was created
     * @param _ipfsHash IPFS hash for artifact documentation/images
     * @return artifactId The ID of the newly registered artifact
     */
    function registerArtifact(
        string calldata _name,        // calldata saves gas vs memory
        string calldata _description,
        string calldata _origin,
        uint96 _yearOfCreation,       // uint96 instead of uint256
        string calldata _ipfsHash
    ) external returns (uint256 artifactId) {
        
        // Use unchecked for counter increment (safe from overflow in practice)
        unchecked {
            artifactId = ++artifactCount;
        }
        
        // Create artifact struct
        Artifact storage newArtifact = artifacts[artifactId];
        newArtifact.name = _name;
        newArtifact.description = _description;
        newArtifact.origin = _origin;
        newArtifact.yearOfCreation = _yearOfCreation;
        newArtifact.currentOwner = msg.sender;
        newArtifact.ipfsHash = _ipfsHash;
        // verifier, verificationTimestamp, and isVerified default to zero/false
        
        // Record initial ownership
        ownershipHistory[artifactId].push(OwnershipHistory({
            owner: msg.sender,
            timestamp: uint40(block.timestamp),
            price: 0
        }));
        
        emit ArtifactRegistered(artifactId, _name, msg.sender);
    }
    
    /**
     * @dev Verify an artifact's authenticity (only authorized verifiers)
     * @param _artifactId ID of the artifact to verify
     */
    function verifyArtifact(uint256 _artifactId) 
        external 
        onlyVerifier 
        validArtifactId(_artifactId) 
    {
        Artifact storage artifact = artifacts[_artifactId];
        
        if (artifact.isVerified) revert AlreadyVerified();
        
        artifact.isVerified = true;
        artifact.verifier = msg.sender;
        artifact.verificationTimestamp = uint40(block.timestamp);
        
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
    ) external onlyArtifactOwner(_artifactId) validArtifactId(_artifactId) {
        
        if (_newOwner == address(0)) revert InvalidAddress();
        if (_newOwner == msg.sender) revert CannotTransferToSelf();
        
        address previousOwner = artifacts[_artifactId].currentOwner;
        artifacts[_artifactId].currentOwner = _newOwner;
        
        // Record ownership change
        ownershipHistory[_artifactId].push(OwnershipHistory({
            owner: _newOwner,
            timestamp: uint40(block.timestamp),
            price: uint216(_price)  // Safe cast: validate if needed for your use case
        }));
        
        emit OwnershipTransferred(_artifactId, previousOwner, _newOwner, _price);
    }
    
    /**
     * @dev Authorize a new verifier (only admin)
     * @param _verifier Address of the verifier to authorize
     */
    function authorizeVerifier(address _verifier) external onlyAdmin {
        if (_verifier == address(0)) revert InvalidAddress();
        if (authorizedVerifiers[_verifier]) revert VerifierAlreadyAuthorized();
        
        authorizedVerifiers[_verifier] = true;
        emit VerifierAuthorized(_verifier);
    }
    
    /**
     * @dev Revoke verifier authorization (only admin)
     * @param _verifier Address of the verifier to revoke
     */
    function revokeVerifier(address _verifier) external onlyAdmin {
        if (!authorizedVerifiers[_verifier]) revert VerifierNotAuthorized();
        if (_verifier == admin) revert CannotRevokeAdmin();
        
        authorizedVerifiers[_verifier] = false;
        emit VerifierRevoked(_verifier);
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @dev Get complete artifact information
     * @param _artifactId ID of the artifact
     * @return artifact The complete artifact struct
     */
    function getArtifact(uint256 _artifactId) 
        external 
        view 
        validArtifactId(_artifactId)
        returns (Artifact memory artifact) 
    {
        return artifacts[_artifactId];
    }
    
    /**
     * @dev Get ownership history of an artifact
     * @param _artifactId ID of the artifact
     * @return history Array of ownership records
     */
    function getOwnershipHistory(uint256 _artifactId) 
        external 
        view 
        validArtifactId(_artifactId)
        returns (OwnershipHistory[] memory history) 
    {
        return ownershipHistory[_artifactId];
    }
    
    /**
     * @dev Get total number of artifacts registered
     * @return Total artifact count
     */
    function getTotalArtifacts() external view returns (uint256) {
        return artifactCount;
    }
    
    /**
     * @dev Check if an address is an authorized verifier
     * @param _address Address to check
     * @return bool True if authorized
     */
    function isAuthorizedVerifier(address _address) external view returns (bool) {
        return authorizedVerifiers[_address];
    }
    
    /**
     * @dev Get artifact verification status
     * @param _artifactId ID of the artifact
     * @return isVerified Whether the artifact is verified
     * @return verifier Address of the verifier (if verified)
     * @return timestamp Verification timestamp (if verified)
     */
    function getVerificationStatus(uint256 _artifactId) 
        external 
        view 
        validArtifactId(_artifactId)
        returns (
            bool isVerified,
            address verifier,
            uint256 timestamp
        ) 
    {
        Artifact storage artifact = artifacts[_artifactId];
        return (
            artifact.isVerified,
            artifact.verifier,
            artifact.verificationTimestamp
        );
    }
}
