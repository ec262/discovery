# Abstract base class for application exceptions
class DiscoveryServiceException < StandardError
  def status_code; end
  def response; end
end

class InsufficientCredits < DiscoveryServiceException
  def initialize(available_credits, needed_credits)
    @available_credits = available_credits
    @needed_credits = needed_credits
  end
  
  def status_code; 406 end
  
  def response
    { :error => "Insufficient credits",
      :available_credits => @available_credits,
      :needed_credits => @needed_credits
    }
  end
end

class UnknownChunk < DiscoveryServiceException
  def status_code; 404 end
  
  def response
    { :error => "Unknown chunk" }
  end
end

class UnknownClient < DiscoveryServiceException
  def status_code; 404 end
  
  def response
    { :error => "Unknown client" }
  end
end