# Brimir is a helpdesk system that can be used to handle email support requests.
# Copyright (C) 2012-2014 Ivaldi http://ivaldi.nl
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'test_helper'
require "minitest/spec"
require "minitest/mock"

describe GpgMailerPatch do
  class MockImplementation
    attr_accessor :headers
    def initialize
      @headers = {}
    end

    def mail(headers, &block)
      @headers = headers
    end

    include GpgMailerPatch
  end

  let(:instance) { MockImplementation.new }

  it "should respond to mail and that would call mail_with_brimir" do
    assert instance.respond_to? :mail
    assert instance.respond_to? :mail_with_brimir
    assert instance.respond_to? :mail_without_brimir
    instance.expects(:mail_without_brimir)
    instance.mail {}
  end

  it "should assign password" do
    oldpassword = AppSettings.gpg_mail_private_key_passphrase
    AppSettings.gpg_mail_private_key_passphrase = "something"
    instance.mail gpg: { sign: true }
    assert instance.headers[:gpg][:password] == "something"
    AppSettings.gpg_mail_private_key_passphrase = oldpassword
  end

  it "should assign sign" do
    AppSettings.gpg_mail_always_sign_outgoing_mail = true
    instance.mail {}
    assert instance.headers[:gpg][:sign] == true
    AppSettings.gpg_mail_always_sign_outgoing_mail = false
  end

  it "should assign encrypt" do
    AppSettings.gpg_mail_always_encrypt_outgoing_mail = true
    instance.mail {}
    assert instance.headers[:gpg][:encrypt] == true
    AppSettings.gpg_mail_always_encrypt_outgoing_mail = false
  end

  it "should remove encrypt when fail to get public key" do
    GpgMailHelper.expects(:assure_public_key_available).returns(false)
    instance.mail gpg: { sign: true, encrypt: true }, to: 'testclient@example.com'  
    assert instance.headers[:gpg][:encrypt] == false
  end

  it "should remove gpg option altogether when no sign and encrypt will be done" do
    instance.mail gpg: { sign: false, encrypt: false }
    assert instance.headers[:gpg].nil?
  end

end
