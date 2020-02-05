require 'yaml'
require './InquiryMailParse'
require './TracInfo'
require './SpInfo'
require 'openssl'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

spSetting = YAML.load_file("sp_setting.yml")
spInfo = SpInfo.new(spSetting)

inquiryMail = InquiryMailParse.new(spSetting)
trac = TracInfo.new(spSetting, spInfo.getConsultantList,
  spInfo.getCustomerList, spInfo.getBoardNameList, spInfo.getWikiLinkList)

items, errorCnt = inquiryMail.getInquirys
ret = trac.createOrUpdateTicket(items)
execNums = ret[0]
errorMsgs = ret[1]
inquiryMail.setUnSeen(errorMsgs) unless errorMsgs.empty?
p "作成又は更新されたチケット番号"
p execNums
exit(errorCnt == 0 && errorMsgs.empty?)