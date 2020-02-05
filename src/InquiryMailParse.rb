require 'net/imap'
require 'kconv'
require "date"

class InquiryMailParse
  
  IMAP_PORT = 993
  IMAP_USESSL = true
  IMAP_MAILBOX = "INBOX"
  SEARCH_CRITERIAS = ["FROM", "support@worksap.co.jp", "UNSEEN"] #未読のみ取得  UNSEEN 
  SUBJECT_ATTR_NAME = "BODY[HEADER.FIELDS (SUBJECT)]" #件名取得の設定
  BODY_ATTR_NAME = "BODY[TEXT]" #メール本文取得の設定
  
  IMAP_PORT.freeze
  IMAP_USESSL.freeze
  IMAP_MAILBOX.freeze
  SUBJECT_ATTR_NAME.freeze
  BODY_ATTR_NAME.freeze
  
  def initialize(spSetting)
    @IMAP_HOST = spSetting["IMAP_HOST"]
    @IMAP_USER = spSetting["IMAP_USER"]
    @IMAP_PASSWD = spSetting["IMAP_PASSWD"]
  end
  
  def getInquirys
    ret = []
    imap = getImapSetting
    errorCnt = 0
    begin
      #未読メールを検索
      imap.search(SEARCH_CRITERIAS).each do |msg_id|
        msg = imap.fetch(msg_id, [SUBJECT_ATTR_NAME, BODY_ATTR_NAME]).first
        subject = msg.attr[SUBJECT_ATTR_NAME].toutf8.strip
        body = msg.attr[BODY_ATTR_NAME].toutf8.strip
        p "***************** subject " + subject
        #p "***************** body " + body
        items = parseBody(body);
  
        items["subject"] = subject
        items["body"] = body.gsub(/(?![\r\n\t ])[[:cntrl:]]/, '')
        items["message_id"] = msg_id
        if items["thread_id"].nil? || items["secondary_number"].nil? 
          errorCnt += 1
          p "*************************** error no thread_id or secondary_number"
          p subject
          p body
        else
          ret.push(items)
        end
      end
    rescue => e
      p e.class
      p e.message
      p e.backtrace
    end
    imap.store(ret.collect {|item| item["message_id"]}, "+FLAGS", [:Seen]) unless ret.empty? #既読にする
    imap.logout
    ret.sort_by! {|items|
      [items["thread_id"], items["secondary_number"]]
    }
    return ret, errorCnt
  end
  def setUnSeen(ids)
    p "エラーが発生したため未読処理を行います。未読処理対象メッセージID: #{ids}"
    unSeenIds = []
    imap = getImapSetting
    imap.store(ids, "-FLAGS", [:Seen]) unless ids.empty? #未読にする
    imap.logout
  end
  private
  def getImapSetting
    imap = Net::IMAP.new(@IMAP_HOST, IMAP_PORT, IMAP_USESSL)
    imap.login(@IMAP_USER, @IMAP_PASSWD)
    imap.select(IMAP_MAILBOX)
    return imap
  end
  #今は使ってないけど将来的に使いそうな項目もparseしとく
  def parseBody(body)
    ret = {}
    isCreate = true
    numCnt = 0
    body.each_line {|line|
      lineData = line.chomp
      if /^掲示板名\s+:.+/x =~ lineData then
        ret["board_name"] = getValue(lineData, ":")
      end
      if /^\[\d.+\/\d{3}\]/x =~ lineData then
        if numCnt == 0 then
          threadNumber = lineData[1..(lineData.index("]") - 1)].split("/")
          ret["thread_id"] = threadNumber[0].to_i
          ret["secondary_number"] = threadNumber[1].to_i
        end
        numCnt += 1
      end
      if /^対応状況\s+:.+/x =~ lineData then
        ret["status"] = getValue(lineData, ":")
      end
      if /^製品\s+:.+/x =~ lineData then
        ret["product"] = getValue(lineData, ":")
      end
      if /^Version\s+:.+/x =~ lineData then
        ret["version"] = getValue(lineData, ":")
      end
      #@SP側で予告無しに日付書式が変わることがあるので一旦無効化
      #if /^記入日\s+:.+/x =~ lineData then
      #  entered = lineData[(lineData.index(":") + 1)..-1]
      #  entered.strip!
      #  ret["entered"] = DateTime.strptime(entered, "%Y年 %m月 %d日 %H:%M")
      #end
      if /^添付\s+:.+/x =~ lineData then
        ret["attachment"] = getValue(lineData, ":")
      end
      if /^お客様名\s+：.+/x =~ lineData then #お客様名の「：」だけなぜか全角（@SP側のバグ？）
        ret["customer"] = getValue(lineData, "：")
      end
      if /^https:\/\/support\.worksap\.co\.jp\/mailLink\.do.+/x =~ lineData then
        ret["url"] = lineData.strip
      end
    }
    return ret
  end
  def getValue(lineData, splitStr)
    val = lineData.split(splitStr)[1]
    return val.strip
  end
end