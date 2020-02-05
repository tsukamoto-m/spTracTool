require 'xmlrpc/client'

class TracInfo
  
  TICKET_STATUS_VERIFYING = "verifying"
  TICKET_STATUS_DOCUMENT_REVIEWING = "document_reviewing"
  TICKET_STATUS_REOPENED = "reopened"
  TICKET_STATUS_CLOSED = "closed"

  TICKET_CC_CUSTOM = "sdk-qa@ariel-networks.com"
  TICKET_CC_QA = "AAE_Support@ariel-networks.com"
  
  TICKET_CUSTOM_PRODUCT = ["Ariel/AquaDesigner・ワークフロー"] #今後増えるかもしれないので複数にしとく
  
  SP_CLOSED_STATUS = ["解決済", "了解済"]
    
  TICKET_STATUS_VERIFYING.freeze
  TICKET_STATUS_DOCUMENT_REVIEWING.freeze
  TICKET_STATUS_REOPENED.freeze
  TICKET_STATUS_CLOSED.freeze
  TICKET_CC_CUSTOM.freeze
  TICKET_CC_QA.freeze
  
  def initialize(spSetting, consultantList, customerList, boardNameList, wikiLinkList)
    tracUser = spSetting["TRAC_USER"]
    tracPass = spSetting["TRAC_PASS"]
    @TRAC_URL = "http://#{tracUser}:#{tracPass}@" + spSetting["TRAC_XMLRPC_PATH"]
    @CONSULTANT_LIST = consultantList
    @CUSTOMER_LIST = customerList
    @BOARDNAME_LIST = boardNameList
    @WIKILINK_LIST = wikiLinkList
  end

  def createOrUpdateTicket(items)
    ret = []
    errorMsgIds = []
    threadId = ""
    ticketNum = nil
    items.each_with_index {|item, index|
      begin
        if threadId != item["thread_id"] then
          threadId = item["thread_id"]
          ticketNum = getTicketNumber(threadId)
        end
        if ticketNum.nil? then
          ret.push(createTicket(item))
        else
          ret.push(ticketNum)
          updateTicket(ticketNum, item)
        end
      rescue => e
        p "Tracへの接続処理中にエラーが発生しました*************************************"
        p "エラー発生メールの題名： #{item['subject']}"
        p "エラー発生メールのスレッド番号： #{item['thread_id']}"
        p e.class
        p e.message
        p e.backtrace
        errorMsgIds.concat(items.slice(index..-1).collect {|item| item["message_id"]})
        break
      end
    }
    return [ret, errorMsgIds]
  end
  private
  def createSummary(item)
    subject = item["subject"]
    subject = subject[(subject.index(":") + 1)..-1]
    subject.strip!
    return "【" + (item["customer"] || "") + "】 " + subject
  end
  def createDescription(item)
    description = ["問い合わせが届きました。",
                   "{{{",
                   item["body"],
                   "}}}"]
    if item["attachment"] == "あり" then
      description.push("//ファイルが添付されています。//")
    end
    description.push("返信はこちら: #{item["url"]}")
    return description.join("\n")
  end
  def createWikiLinkSentence(item)
    customer = item["customer"]
    wikiLinkList = @WIKILINK_LIST.find {|n|
      !customer.nil? && customer.include?(n["spCustomerName"])
    }
    return  wikiLinkList ? "\n顧客情報はこちら: #{wikiLinkList["tracWikiLink"]}" : ""
  end

  def createAttr(item)
    attrs = {}
    milestone = ""
    product = item["product"]
    customer = item["customer"]
    boardName = item["board_name"]
    consultantList = @CONSULTANT_LIST.find {|n|
      !customer.nil? && customer.include?(n["customerName"])
    }
    customerList = @CUSTOMER_LIST.find {|n|
      !customer.nil? && customer.include?(n["spCustomerName"])
    }
    boardNameList = @BOARDNAME_LIST.find {|n|
      boardName.equal?(n["boardName"])
    }
    
    if /.+カスタム/x =~ product || TICKET_CUSTOM_PRODUCT.include?(product) then
      milestone = "カスタムアプリ/QA"
      attrs["component"] = "QA"
      attrs["cc"] = consultantList.nil? ? TICKET_CC_CUSTOM : consultantList["consultant"].split("\r\n").push(TICKET_CC_CUSTOM).join(",")
    else
      milestone = "QA"
      attrs["component"] = "QA"
      attrs["cc"] = consultantList.nil? ? TICKET_CC_QA : consultantList["consultant"].split("\r\n").push(TICKET_CC_QA).join(",")
    end
    milestone = boardNameList["milestone"] unless boardNameList.nil?
    attrs["owner"] = boardNameList["owner"] unless boardNameList.nil?
    attrs["milestone"] = milestone
    attrs["customer"] = customerList["tracCustomerName"] unless customerList.nil?
    attrs["reporter"] = "ariel_support"
    attrs["keywords"] = "support"
    attrs["thread_id"] = item["thread_id"].to_s
    return attrs
  end

  def createTicket(item)
    summary = createSummary(item)
    description = createDescription(item) + createWikiLinkSentence(item)
    attrs = createAttr(item)
    ticketId = tracAccess("ticket.create", summary, description, attrs)
    return ticketId
  end
  def updateTicket(ticketId, item)
    attrs = {}
    isClosed = false
    description = createDescription(item)
    if isCompleted(item) then
      attrs["resolution"] = "fixed"
      attrs["status"] = TICKET_STATUS_CLOSED
    else
      ticket = getTicket(ticketId)[3]
      attrs["status"] = TICKET_STATUS_REOPENED if [TICKET_STATUS_DOCUMENT_REVIEWING, TICKET_STATUS_VERIFYING, TICKET_STATUS_CLOSED].include?(ticket["status"])
    end
    tracAccess("ticket.update", ticketId.to_i, description, attrs)
  end
  def isCompleted(item)
    status = item["status"]
    return SP_CLOSED_STATUS.include?(status)
  end
  def getTicketNumber(threadId)
    ret = tracAccess("ticket.query", "thread_id=" + threadId.to_s)
    return ret[0]
  end
  def getTicket(ticketId)
    return tracAccess("ticket.get", ticketId.to_i)
  end
  def tracAccess(action, p1, p2=nil, attrs=nil)
    resp = nil
    server = XMLRPC::Client.new2(@TRAC_URL)
    resp = server.call(action, p1) if p2.nil? && attrs.nil?
    resp = server.call(action, p1, p2, attrs, true) unless p2.nil? && attrs.nil?
    return resp
  end
end