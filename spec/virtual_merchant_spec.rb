require 'spec_helper'
require 'virtual_merchant'
require 'yaml'
data = YAML.load_file "config.yml"
demo_creds = data['demo_credentials']

##Useful vars ################################################################
  serial  = "2F9CFB042D001600"
  valid_creds = VirtualMerchant::Credentials.new(
    account_id: demo_creds['account_id'],
    user_id:    demo_creds["user_id"],
    pin:        demo_creds["pin"],
    referer:    demo_creds["referer"],
    demo:       demo_creds['demo'])

  invalid_creds = VirtualMerchant::Credentials.new(
    account_id: 111,
    user_id:    222,
    pin:        "abc",
    referer:    "https://thisisauri.com")

  #this is a test card used by VM.  If it appears on any real batch, that entire
  #batch will be invalid.  Use with caution.
  valid_cc = VirtualMerchant::CreditCard.new(
    name_on_card:  "Lee M Cardholder",
    number:        "5000300020003003",
    expiration:    "0515",
    security_code: "1234")

  invalid_cc = VirtualMerchant::CreditCard.new(
    name_on_card:  "Lee M Cardholder",
    number:        "1234567890123456",
    expiration:    "0513",
    security_code: "1234")

  track_1 = "474F492133496797C161C26752F61C74E094539003DFE7F70F2F51113C2CA457940157EA7D1449BED4E7CE9AEC1416D9"
  track_2 = "EB442E8F4A9357086AF17D57B6EDFB6D99749F4DD78182FD07D57A343EAC3B1B90DC3F5E26D6505D"
  encrypted_cc = VirtualMerchant::CreditCard.from_swipe({
    encrypted: true,
    track_1: track_1,
    track_2: track_2,
    device_type: "audio",
    last_four:   "1234"})

  amount            = VirtualMerchant::Amount.new(total: 0.01,
                                                  next_payment_date: '11/01/2013',
                                                  billing_cycle: 'WEEKLY')

  approval_xml      = File.read("spec/support/approval_response.xml")
  bad_approval_xml  = File.read("spec/support/bad_approval_response.xml")
  error_xml         = File.read("spec/support/error_response.xml")
  declined_void_xml = File.read("spec/support/declined_void_response.xml")
##Useful vars ################################################################

describe VirtualMerchant, vcr: true do
  it "Talks to Virtual Merchant" do
    response = VirtualMerchant.charge(invalid_cc, amount, invalid_creds)
    response.should_not be_approved
  end

  context "no connection to VM", vcr: false do
    it "generates an error response" do
      stub_request(:any, "demo.myvirtualmerchant.com")
        .to_raise(StandardError)
      response = VirtualMerchant.charge(valid_cc, amount, valid_creds)
      response.should_not be_approved
    end
  end

  describe "Charging a card" do
    context "Manual entry" do
      context "Happy Approval" do
        it "generates an approval response" do
          response = VirtualMerchant.charge(valid_cc, amount, valid_creds)
          response.should be_approved
        end
      end
      context "Un-Happy Approval", vcr: false do
        it "generates an error response" do
          stub_request(:any, "demo.myvirtualmerchant.com")
            .with(body: bad_approval_xml)
          response = VirtualMerchant.charge(valid_cc, amount, valid_creds)
          response.should_not be_approved
        end
      end
      context "Straight error response" do
        it "generates an error response" do
          response = VirtualMerchant.charge(invalid_cc, amount, valid_creds)
          response.should be_an_instance_of VirtualMerchant::Response
          response.should_not be_approved
        end
      end
    end

    context "encrypted swipe" do
      it 'generates an approval response'

      it "generates a declined response" do
        response = VirtualMerchant.charge(encrypted_cc, amount, valid_creds)
        response.should_not be_approved
      end
    end
  end
  describe 'Recurring Payments' do
    it 'generates an approval response'

    xit 'generates a declined response' do
      response = VirtualMerchant.add_recurring(valid_cc, amount, invalid_creds)
      response.should_not be_approved
    end
  end

  describe "Authorizing a card" do
    context 'Manual entry' do
      it 'generates an approval response' do
        response = VirtualMerchant.authorize(valid_cc, amount, valid_creds)
        response.should be_approved
      end

      it 'generates a declined response' do
        response = VirtualMerchant.authorize(invalid_cc, amount, valid_creds)
        response.should_not be_approved
      end
    end

    context 'Encrypted swipe' do
      xit 'generates an approval response' do
        response = VirtualMerchant.authorize(encrypted_cc, amount, valid_creds)
        response.should be_approved
      end

      it 'generates a declined response'
    end
  end

  describe 'Completing an authorized transaction' do
    it 'generates an approval response' do
      amount.total = 0.15
      transaction = VirtualMerchant.authorize(valid_cc, amount, valid_creds)
      valid_creds.transaction_id = transaction.transaction_id
      response = VirtualMerchant.complete(valid_cc, amount, valid_creds)
      response.should be_approved
    end

    it 'generates a declined response' do
      transaction = VirtualMerchant.authorize(valid_cc, amount, valid_creds)
      valid_creds.transaction_id = transaction.transaction_id
      response = VirtualMerchant.complete(valid_cc, amount, invalid_creds)
      response.should_not be_approved
    end
  end

  describe 'Deleting an authorized transaction' do
    it 'generates an approval response' do
      transaction = VirtualMerchant.authorize(valid_cc, amount, valid_creds)
      valid_creds.transaction_id = transaction.transaction_id
      response    = VirtualMerchant.delete(valid_cc, amount, valid_creds)
      response.should be_approved
    end

    it 'generates a declined response' do
      transaction = VirtualMerchant.authorize(valid_cc, amount, valid_creds)
      valid_creds.transaction_id = transaction.transaction_id
      response    = VirtualMerchant.delete(valid_cc, amount, invalid_creds)
      response.should_not be_approved
    end
  end

  describe "Refunding a card" do
    context "Happy Approval" do
      it "generates an approval response" do
        response = VirtualMerchant.refund(valid_cc, amount, valid_creds)
        response.should be_approved
      end
    end
    context "Un-Happy Approval", vcr: false do
      it "generates an error response" do
        stub_request(:any, "demo.myvirtualmerchant.com")
          .with(body: bad_approval_xml)
        response = VirtualMerchant.refund(valid_cc, amount, valid_creds)
        response.should_not be_approved
      end
    end
    context "Straight error response" do
      it "generates an error response" do
        response = VirtualMerchant.refund(invalid_cc, amount, valid_creds)
        response.should_not be_approved
      end
    end
  end

  describe "Voiding a card" do
    context "successful void" do
      it "generates an approval response" do
        response = VirtualMerchant.charge(valid_cc, amount, valid_creds)
        response = VirtualMerchant.void(response.transaction_id, valid_creds)
        response.should be_approved
      end
    end
    context "failed void" do
      it "generates an error response" do
        response = VirtualMerchant.void(123, valid_creds)
        response.should_not be_approved
      end
    end
  end
end
