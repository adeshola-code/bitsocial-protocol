;; BitSocial Protocol - Bitcoin-Native Social Infrastructure
;; 
;; Summary:
;; A comprehensive decentralized social networking protocol built on Stacks Layer 2,
;; enabling censorship-resistant content creation, peer-to-peer value exchange,
;; and community-driven governance with Bitcoin-level security guarantees.
;;
;; Description:
;; BitSocial represents the next evolution of social media infrastructure, combining
;; the immutable security of Bitcoin with the programmability of smart contracts.
;; This protocol establishes a foundation for truly decentralized social applications
;; where users maintain complete ownership of their identity, content, and social
;; connections. Through innovative tokenomics and reputation systems, BitSocial
;; creates sustainable incentive structures that reward authentic engagement while
;; preventing spam and manipulation. The protocol's modular architecture enables
;; seamless integration with existing applications and provides developers with
;; powerful primitives for building the next generation of social experiences.
;;
;; Core Features:
;; - Sovereign digital identities with cryptographic verification
;; - Content monetization through micro-payments and tip economy
;; - Reputation-based governance with anti-sybil mechanisms
;; - Permissionless community creation with native token support
;; - Composable social graphs for cross-platform interoperability
;; - Bitcoin-secured finality ensuring permanent data availability

;; PROTOCOL CONSTANTS

(define-constant CONTRACT_OWNER tx-sender)

;; Error Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_INVALID_PARAMS (err u105))
(define-constant ERR_PROFILE_NOT_FOUND (err u106))
(define-constant ERR_CONTENT_NOT_FOUND (err u107))
(define-constant ERR_ALREADY_TIPPED (err u108))
(define-constant ERR_SELF_TIP (err u109))
(define-constant ERR_COMMUNITY_EXISTS (err u110))
(define-constant ERR_INVALID_URL (err u111))
(define-constant ERR_INVALID_MESSAGE (err u112))

;; Protocol Configuration Constants
(define-constant PROTOCOL_FEE_BPS u250)        ;; 2.5% protocol fee in basis points
(define-constant MIN_TIP_AMOUNT u1000)         ;; Minimum tip amount in microSTX
(define-constant MAX_HANDLE_LENGTH u32)        ;; Maximum character length for handles
(define-constant MAX_BIO_LENGTH u256)          ;; Maximum character length for bio
(define-constant MAX_CONTENT_LENGTH u1024)     ;; Maximum character length for content
(define-constant MAX_URL_LENGTH u256)          ;; Maximum character length for URLs
(define-constant MAX_MESSAGE_LENGTH u256)      ;; Maximum character length for messages
(define-constant INITIAL_REPUTATION u100)     ;; Starting reputation score for new users

;; PROTOCOL STATE VARIABLES

(define-data-var protocol-fee-recipient principal CONTRACT_OWNER)
(define-data-var next-profile-id uint u1)
(define-data-var next-content-id uint u1)
(define-data-var next-community-id uint u1)
(define-data-var protocol-paused bool false)

;; DATA STRUCTURES

;; User Identity and Profile Management
(define-map user-profiles
  { profile-id: uint }
  {
    owner: principal,
    handle: (string-ascii 32),
    bio: (string-utf8 256),
    avatar-url: (optional (string-ascii 256)),
    reputation-score: uint,
    total-tips-received: uint,
    total-tips-sent: uint,
    content-count: uint,
    follower-count: uint,
    following-count: uint,
    created-at: uint,
    verified: bool
  }
)

;; Handle Resolution System
(define-map handle-to-profile (string-ascii 32) uint)
(define-map principal-to-profile principal uint)

;; Content and Media Storage
(define-map content-posts
  { content-id: uint }
  {
    author-id: uint,
    content-text: (string-utf8 1024),
    content-type: (string-ascii 5),
    media-url: (optional (string-ascii 256)),
    tip-count: uint,
    total-tips: uint,
    engagement-score: uint,
    created-at: uint,
    community-id: (optional uint)
  }
)

;; Monetization and Tipping System
(define-map content-tips
  { content-id: uint, tipper: principal }
  {
    amount: uint,
    message: (optional (string-utf8 256)),
    tipped-at: uint
  }
)

;; Social Connection Graph
(define-map social-connections
  { follower-id: uint, following-id: uint }
  { connected-at: uint }
)

;; Community and Governance Infrastructure
(define-map communities
  { community-id: uint }
  {
    name: (string-ascii 64),
    description: (string-utf8 256),
    creator-id: uint,
    token-symbol: (string-ascii 8),
    total-supply: uint,
    member-count: uint,
    created-at: uint,
    governance-threshold: uint
  }
)

;; Community Membership and Token Distribution
(define-map community-members
  { community-id: uint, member-id: uint }
  {
    token-balance: uint,
    joined-at: uint,
    is-moderator: bool
  }
)

;; Reputation and Engagement Tracking
(define-map user-engagement
  { profile-id: uint, period: uint }
  {
    tips-received: uint,
    tips-sent: uint,
    content-posted: uint,
    engagement-score: uint
  }
)

;; UTILITY FUNCTIONS

(define-private (is-valid-handle (handle (string-ascii 32)))
  (and 
    (> (len handle) u0)
    (<= (len handle) MAX_HANDLE_LENGTH)
    (is-none (map-get? handle-to-profile handle))
  )
)

(define-private (is-valid-url (url (string-ascii 256)))
  (and
    (> (len url) u0)
    (<= (len url) MAX_URL_LENGTH)
    (or
      (is-eq (unwrap-panic (slice? url u0 u7)) "http://")
      (is-eq (unwrap-panic (slice? url u0 u8)) "https://")
    )
  )
)

(define-private (is-valid-optional-url (url (optional (string-ascii 256))))
  (match url
    some-url (is-valid-url some-url)
    true
  )
)

(define-private (is-valid-message (message (optional (string-utf8 256))))
  (match message
    some-msg (<= (len some-msg) MAX_MESSAGE_LENGTH)
    true
  )
)

(define-private (is-valid-content-type (content-type (string-ascii 5)))
  (let ((valid-types (list "text" "image" "video" "audio" "link")))
    (is-some (index-of valid-types content-type))
  )
)

(define-private (calculate-protocol-fee (amount uint))
  (/ (* amount PROTOCOL_FEE_BPS) u10000)
)

(define-private (get-current-period)
  (/ stacks-block-height u2016)
)

(define-private (update-reputation (profile-id uint) (points uint))
  (let ((profile (unwrap! (map-get? user-profiles { profile-id: profile-id }) false)))
    (map-set user-profiles
      { profile-id: profile-id }
      (merge profile { reputation-score: (+ (get reputation-score profile) points) })
    )
    true
  )
)