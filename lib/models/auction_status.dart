/// Represents the possible statuses of an auction
enum AuctionStatus {
  /// Auction is active and open for bidding
  active,
  
  /// Auction has ended but not yet finalized
  ended,
  
  /// Auction has been finalized
  finalized,
  
  /// Auction has been cancelled
  cancelled,
}
