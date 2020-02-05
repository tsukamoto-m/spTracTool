require "net/http"
require "csv"
require "uri"
require "rexml/document"
include REXML

class SpInfo
  
  GIGAN_API_EXPORT_PATH = "api/export"
  BOARD_NAME_TYPE = "W1TXWPX3"
  BOARD_NAME_EXA = "default"
  CONSULTANT_TYPE = "W1TXWPX3FV"
  CONSULTANT_EXA = "m1nf89im"
  CUSTOMER_TYPE = "W1TXWPX35Z"
  CUSTOMER_EXA = "xfaequvl"
  WIKI_LINK_TYPE = "W1TXWPX3X0"
  WIKI_LINK_EXA = "nm08qo38"
  WORK_CSV_FILE_NAME = "work.csv"
  
  BOARDNAME_MESSAGE_1 = "giganからの掲示板名取得に失敗しました。掲示板名とマイルストーンの連携は行われません。"
  BOARDNAME_MESSAGE_2 = "giganの接続が設定されていない為、掲示板名とマイルストーンの連携は行われません。"
  CONSULTANT_MESSAGE_1 = "giganからの担当者取得に失敗しました。お客様毎の担当者取得は行われません。"
  CONSULTANT_MESSAGE_2 = "giganの接続が設定されていない為、お客様毎の担当者取得は行われません。"
  CUSTOMER_MESSAGE_1 = "giganからのCustomer情報取得に失敗しました。Customerの設定は行われません。"
  CUSTOMER_MESSAGE_2 = "giganの接続が設定されていない為、Customerの設定は行われません。"
  WIKI_LINK_MESSAGE_1 = "giganからの顧客情報リンク取得に失敗しました。お客様毎の顧客情報リンクの取得は行われません。"
  WIKI_LINK_MESSAGE_2 = "giganの接続が設定されていない為、お客様毎の顧客情報リンクの取得は行われません。"

  GIGAN_API_EXPORT_PATH.freeze
  BOARD_NAME_TYPE.freeze
  BOARD_NAME_EXA.freeze
  CONSULTANT_TYPE.freeze
  CONSULTANT_EXA.freeze
  CUSTOMER_TYPE.freeze
  CUSTOMER_EXA.freeze
  WIKI_LINK_TYPE.freeze
  WIKI_LINK_EXA.freeze
  WORK_CSV_FILE_NAME.freeze
  BOARDNAME_MESSAGE_1.freeze
  BOARDNAME_MESSAGE_2.freeze
  CONSULTANT_MESSAGE_1.freeze
  CONSULTANT_MESSAGE_2.freeze
  CUSTOMER_MESSAGE_1.freeze
  CUSTOMER_MESSAGE_2.freeze
  WIKI_LINK_MESSAGE_1.freeze
  WIKI_LINK_MESSAGE_2.freeze

  def initialize(spSetting)
    @GIGAN_URL = spSetting["GIGAN_URL"]
    @GIGAN_USER = spSetting["GIGAN_USER"]
    @GIGAN_PASS = spSetting["GIGAN_PASS"]
    @GIGAN_MASTER_APPID = spSetting["GIGAN_MASTER_APPID"]
  end
  
  def getBoardNameList
    mylist = getCsvList(BOARD_NAME_TYPE, BOARD_NAME_EXA, BOARDNAME_MESSAGE_1, BOARDNAME_MESSAGE_2) { |ret, row|
      ret.push({"boardName" => row["title"], "milestone" => row["milestone"], "owner" => row["owner"]})
    }
    return mylist
  end

  def getConsultantList
    mylist = getCsvList(CONSULTANT_TYPE, CONSULTANT_EXA, CONSULTANT_MESSAGE_1, CONSULTANT_MESSAGE_2) { |ret, row|
      ret.push({"customerName" => row["title"], "consultant" => row["consultant"]})
    }
    return mylist
  end
  
  def getCustomerList
    mylist = getCsvList(CUSTOMER_TYPE, CUSTOMER_EXA, CUSTOMER_MESSAGE_1, CUSTOMER_MESSAGE_2) { |ret, row|
      ret.push({"spCustomerName" => row["title"], "tracCustomerName" => row["customer"]})
    }
    return mylist
  end

  def getWikiLinkList
    mylist = getCsvList(WIKI_LINK_TYPE, WIKI_LINK_EXA, WIKI_LINK_MESSAGE_1, WIKI_LINK_MESSAGE_2) { |ret, row|
      ret.push({"spCustomerName" => row["title"], "tracWikiLink" => row["wiki_link"]})
    }
    return mylist
  end
  
  private
  def getCsvList(type, exa, errorMessage, noSettingMessage)
    ret = []
    unless @GIGAN_URL.nil? && @GIGAN_USER.nil? && @GIGAN_PASS.nil? && @GIGAN_MASTER_APPID.nil?
      begin
        exportCsv(@GIGAN_MASTER_APPID, type, exa)
        open(WORK_CSV_FILE_NAME, "rb:BOM|UTF-16:UTF-8"){|f|
          CSV.new(f, col_sep: ",", row_sep: "\n", headers: :first_row).each do |row|
            yield ret, row
          end
        }
      rescue => e
        p errorMessage
        p e.class
        p e.message
        p e.backtrace
      end
    else
      p noSettingMessage
    end
    return ret
  end
  def exportCsv(id, type, exa)
    params = Hash.new
    params.store("id", id)
    params.store("type", type)
    params.store("exa", exa)
    res = aquaApiCall(@GIGAN_URL + GIGAN_API_EXPORT_PATH, params) {|url| Net::HTTP::Get.new(url)}
    csvtext = res.body
    open(WORK_CSV_FILE_NAME, "wb"){|f|
      f.write(csvtext)
    }
  end
  def aquaApiCall(apiurl, params, &method)
    url = URI.parse(apiurl)
    url.query = URI.encode_www_form(params)
    req = method.call(url)
    req.basic_auth(@GIGAN_USER, @GIGAN_PASS)
    #TODO , :use_ssl => true 本番機はSSL設定いる
    res = Net::HTTP.start(url.host, url.port, :use_ssl => true) {|http|
      http.request(req)
    }
    return res
  end
end