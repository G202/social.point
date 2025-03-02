// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract PointSocial is Initializable, UUPSUpgradeable, OwnableUpgradeable{
    using Counters for Counters.Counter;
    Counters.Counter internal _postIds;
    Counters.Counter internal _commentIds;
    Counters.Counter internal _likeIds;

    struct Post {
        uint256 id;
        address from;
        bytes32 contents;
        bytes32 image;
        uint256 createdAt;
        uint16 likesCount;
        uint16 commentsCount;
    }

    struct Comment {
        uint256 id;
        address from;
        bytes32 contents;
        uint256 createdAt;
    }

    struct Like {
        uint256 id;
        address from;
        uint256 createdAt;
    }

    struct Profile {
        bytes32 displayName;
        bytes32 displayLocation;
        bytes32 displayAbout;
        bytes32 avatar;
        bytes32 banner;
    }

    event StateChange(
        uint256 postId,
        address indexed from,
        uint256 indexed date,
        Action indexed action
    );


    event ProfileChange(
        address indexed from,
        uint256 indexed date
    );

    uint256[] public postIds;
    mapping(address => uint256[]) public postIdsByOwner;
    mapping(uint256 => Post) public postById;
    mapping(uint256 => uint256[]) public commentIdsByPost;
    mapping(uint256 => Comment) public commentById;
    mapping(address => uint256[]) public commentIdsByOwner;
    mapping(uint256 => uint256[]) public likeIdsByPost;
    mapping(uint256 => Like) public likeById;

    address private _migrator;
    mapping(address => Profile) public profileByOwner;

    enum Action {Migrator, Post, Like, Comment, Edit, Delete}

    function initialize() public initializer onlyProxy {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function addMigrator(address migrator) public onlyOwner {
        require(_migrator == address(0), "Access Denied");
        _migrator = migrator;
        emit StateChange(0, msg.sender, block.timestamp, Action.Migrator);
    }

    // Post data functions
    function addPost(bytes32 contents, bytes32 image) public {
        _postIds.increment();
        uint256 newPostId = _postIds.current();
        Post memory _post = Post(
            newPostId,
            msg.sender,
            contents,
            image,
            block.timestamp,
            0,
            0
        );
        postIds.push(newPostId);
        postById[newPostId] = _post;
        postIdsByOwner[msg.sender].push(newPostId);

        emit StateChange(newPostId, msg.sender, block.timestamp, Action.Post);
    }

    function editPost(uint256 postId, bytes32 contents, bytes32 image) public {
        require(postById[postId].createdAt != 0, "ERROR_POST_DOES_NOT_EXISTS");
        require(msg.sender == postById[postId].from, "ERROR_CANNOT_EDIT_OTHERS_POSTS");

        postById[postId].contents = contents;
        postById[postId].image = image;

        emit StateChange(postId, msg.sender, block.timestamp, Action.Edit);
    }

    function deletePost(uint256 postId) public {
        require(postById[postId].createdAt != 0, "ERROR_POST_DOES_NOT_EXISTS");
        require(msg.sender == postById[postId].from, "ERROR_CANNOT_DELETE_OTHERS_POSTS");
        require(postById[postId].commentsCount == 0, "ERROR_CANNOT_DELETE_POST_WITH_COMMENTS");
        
        delete postById[postId];
        
        emit StateChange(postId, msg.sender, block.timestamp, Action.Delete);
    }

    function getAllPosts() public view returns (Post[] memory) {
        Post[] memory _posts = new Post[](postIds.length);
        for (uint256 i = 0; i < postIds.length; i++) {
            _posts[i] = postById[postIds[i]];
        }
        return _posts;
    }

    function getAllPostsLength() public view returns (uint256) {
        uint256 length = 0;
        for (uint256 i = 0; i < postIds.length; i++) {
            if (postById[postIds[i]].createdAt > 0) {
                length++;
            }
        }
        return length;
    }

    function getPaginatedPosts(uint256 cursor, uint256 howMany) public view returns (Post[] memory) {
        uint256 length = howMany;
        if(length > postIds.length - cursor) {
            length = postIds.length - cursor;
        }

        Post[] memory _posts = new Post[](length);
        for (uint256 i = length; i > 0; i--) {
            _posts[length-i] = postById[postIds[postIds.length - cursor - i]];
        }
        return _posts;
    }

    function getAllPostsByOwner(address owner)
        public
        view
        returns (Post[] memory)
    {
        Post[] memory _posts = new Post[](postIdsByOwner[owner].length);
        for (uint256 i = 0; i < postIdsByOwner[owner].length; i++) {
            _posts[i] = postById[postIdsByOwner[owner][i]];
        }
        return _posts;
    }

    function getAllPostsByOwnerLength(address owner) public view returns (uint256) {
        uint256 length = 0;
        for (uint256 i = 0; i < postIdsByOwner[owner].length; i++) {
            if (postById[postIdsByOwner[owner][i]].createdAt > 0) {
                length++;
            }
        }
        return length;
    }

    function getPaginatedPostsByOwner(address owner, uint256 cursor, uint256 howMany)
    public view returns (Post[] memory) {
        uint256 _ownerPostLength = postIdsByOwner[owner].length;

        uint256 length = howMany;
        if(length > _ownerPostLength - cursor) {
            length = _ownerPostLength - cursor;
        }

        Post[] memory _posts = new Post[](length);
        for (uint256 i = length; i > 0; i--) {
            _posts[length-i] = postById[postIdsByOwner[owner][_ownerPostLength - cursor - i]];
        }
        return _posts;
    }

    function getPostById(uint256 id) public view returns (Post memory) {
        return postById[id];
    }

    // Example: 1,"0x0000000000000000000000000000000000000000000068692066726f6d20706e"
    function addCommentToPost(uint256 postId, bytes32 contents) public {
        _commentIds.increment();
        uint256 newCommentId = _commentIds.current();
        Comment memory _comment = Comment(
            newCommentId,
            msg.sender,
            contents,
            block.timestamp
        );
        commentIdsByPost[postId].push(newCommentId);
        commentById[newCommentId] = _comment;
        commentIdsByOwner[msg.sender].push(newCommentId);
        postById[postId].commentsCount += 1;

        emit StateChange(postId, msg.sender, block.timestamp, Action.Comment);
    }

    function editCommentForPost(uint256 commentId, bytes32 contents) public {
        Comment storage comment = commentById[commentId];
        
        require(comment.createdAt != 0, "ERROR_POST_DOES_NOT_EXISTS");
        require(msg.sender == comment.from, "ERROR_CANNOT_EDIT_OTHERS_COMMENTS");
        comment.contents = contents;

        emit StateChange(commentId, msg.sender, block.timestamp, Action.Edit);
    }

    function deleteCommentForPost(uint256 postId, uint256 commentId) public {
        require(commentById[commentId].createdAt != 0, "ERROR_COMMENT_DOES_NOT_EXISTS");
        require(msg.sender == commentById[commentId].from, "ERROR_CANNOT_DELETE_OTHERS_COMMENTS");

        postById[postId].commentsCount -= 1;
        delete commentById[commentId];

        emit StateChange(commentId, msg.sender, block.timestamp, Action.Delete);
    }

    function getAllCommentsForPost(uint256 postId) public view returns (Comment[] memory)
    {
        Comment[] memory _comments = new Comment[](commentIdsByPost[postId].length);
        for (uint256 i = 0; i < commentIdsByPost[postId].length; i++) {
            _comments[i] = commentById[commentIdsByPost[postId][i]];
        }
        return _comments;
    }

    // Likes data functions
    function addLikeToPost(uint256 postId) public returns(bool) {
        // Get the post and likes for the postId from the mapping
        uint256[] storage _likeIdsOnPost = likeIdsByPost[postId];
        Post storage _post = postById[postId];

        uint256 _removeIndex;
        bool _isLiked = false;
        uint256 _removeId;

        // Check if msg.sender has already liked
        for (uint256 i = 0; i < _likeIdsOnPost.length; i++) {
            if(likeById[_likeIdsOnPost[i]].from == msg.sender) {
                _isLiked = true;
                _removeIndex = i;
                _removeId = _likeIdsOnPost[i];
                break;
            }
        }
        // If yes, then we remove that like and decrement the likesCount for the post
        if(_isLiked) {
            for (uint256 i = _removeIndex; i < _likeIdsOnPost.length - 1; i++) {
                _likeIdsOnPost[i] = _likeIdsOnPost[i+1];
            }
            
            _likeIdsOnPost.pop();
            delete likeById[_removeId];
            _post.likesCount--;
            return false;
        }

        _likeIds.increment();
        uint256 newLikeId = _likeIds.current();
        Like memory _like = Like(newLikeId, msg.sender, block.timestamp);
        _likeIdsOnPost.push(newLikeId);
        likeById[newLikeId] = _like;
        postById[postId].likesCount += 1;

        emit StateChange(postId, msg.sender, block.timestamp, Action.Like);

        return true;
    }

    function checkLikeToPost(uint256 postId) public view returns(bool) {
        uint256[] memory _likeIdsOnPost = likeIdsByPost[postId];

        for (uint256 i = 0; i < _likeIdsOnPost.length; i++) {
            if(likeById[_likeIdsOnPost[i]].from == msg.sender) {
                return true;
            }
        }

        return false;
    }

    function setProfile(bytes32 name_, bytes32 location_, bytes32 about_, bytes32 avatar_, bytes32 banner_) public {
        profileByOwner[msg.sender].displayName = name_;
        profileByOwner[msg.sender].displayLocation = location_;
        profileByOwner[msg.sender].displayAbout = about_;
        profileByOwner[msg.sender].avatar = avatar_;
        profileByOwner[msg.sender].banner = banner_;
        emit ProfileChange(msg.sender, block.timestamp);
    }

    function getProfile(address id_) public view returns (Profile memory) {
        return profileByOwner[id_];
    }

    // Data Migrator Functions - only callable by _migrator

    function add(
        uint256 id,
        address author,
        bytes32 contents,
        bytes32 image,
        uint16 likesCount,
        uint256 createdAt
    ) public {
        require(msg.sender == _migrator, "Access Denied");

            Post memory _post = Post({
                id: id,
                from: author,
                contents: contents,
                image: image,
                createdAt: createdAt,
                likesCount: likesCount,
                commentsCount: 0
            });

            postIds.push(id);
            postIdsByOwner[_post.from].push(id);
            postById[_post.id] = _post;
            _postIds.increment();

            emit StateChange(id, author, block.timestamp, Action.Post);
    }

    function addComment(
        uint256 id,
        uint256 postId,
        address author,
        bytes32 contents,
        uint256 createdAt
    ) public {
        require(msg.sender == _migrator, "Access Denied");

            Comment memory _comment = Comment({
                id: id,
                from: author,
                contents: contents,
                createdAt: createdAt
            });

            commentIdsByPost[postId].push(id);
            commentById[_comment.id] = _comment;
            commentIdsByOwner[_comment.from].push(id);
            _commentIds.increment();
            postById[postId].commentsCount += 1;

            emit StateChange(postId, author, block.timestamp, Action.Comment);
    }

    function addProfile(
        address user,
        bytes32 name,
        bytes32 location,
        bytes32 about,
        bytes32 avatar,
        bytes32 banner
    ) public {
        require(msg.sender == _migrator, "Access Denied");

            profileByOwner[user].displayName = name;
            profileByOwner[user].displayLocation = location;
            profileByOwner[user].displayAbout = about;
            profileByOwner[user].avatar = avatar;
            profileByOwner[user].banner = banner;
            
            emit ProfileChange(user, block.timestamp);
    }

}
