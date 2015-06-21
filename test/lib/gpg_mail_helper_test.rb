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

describe GpgMailHelper do

  def fixture_file(action)
    File.join(Rails.root, 'test', 'fixtures', 'gpg_mail_helper', action)
  end

  def read_fixture(action)
    IO.readlines(fixture_file(action))
  end

  def simple_mail
    Mail.new(read_fixture('simple').join)
  end

  def signed_mail
    Mail.new(read_fixture('testclient.signed.mail').join)
  end

  def badly_signed_mail
    Mail.new(read_fixture('testclient.badlysigned.mail').join)
  end

  def encrypted_mail
    Mail.new(read_fixture('testclient.encrypted.mail').join)
  end

  def encrypted_and_signed_mail
    Mail.new(read_fixture('testclient.encrypted.signed.mail').join)
  end

  before do
    # Import the key
    GPGME::Key.import(File.open fixture_file('testserver.public.key'))
    GPGME::Key.import(File.open fixture_file('testclient.public.key'))
    GPGME::Key.import(File.open fixture_file('testserver.private.key'))
    GPGME::Key.import(File.open fixture_file('testclient.private.key'))
  end

  after do
    # remove the key
    #GPGME::Key.find(:secret, 'testclient@example.com').each { |k| k.delete! allow_secret: true }
    #GPGME::Key.find(:secret, 'testserver@example.com').each { |k| k.delete! allow_secret: true }
  end

  describe "when email encryption is required" do
    before do
      AppSettings.gpg_mail_encryption_required = true
    end
    after do
      AppSettings.gpg_mail_encryption_required = false
    end
    it "should return nil when the email is not encrypted" do
      assert GpgMailHelper.decrypt_if_encrypted(simple_mail).nil?
    end
    it 'should decrypt an encrypted mail' do
      encrypted = encrypted_mail
      assert encrypted.encrypted?
      result = GpgMailHelper.decrypt_if_encrypted encrypted
      assert result[0].encrypted? == false
    end
  end

  describe "when email verification is required" do
    before do
      AppSettings.gpg_mail_verification_required = true
    end
    after do
      AppSettings.gpg_mail_verification_required  = false
    end
    it "should return nil when the email is not signed" do
      assert GpgMailHelper.decrypt_if_encrypted(simple_mail).nil?
    end
    it "should return the email when the email is properly signed" do
      assert GpgMailHelper.decrypt_if_encrypted(signed_mail).present?
    end
    it 'should return nil when the email is encrypted but not signed' do
      assert GpgMailHelper.decrypt_if_encrypted(encrypted_mail).nil?
    end
    it "should return the unencrypted email when the email is properly signed and encrypted" do
      result = GpgMailHelper.decrypt_if_encrypted(encrypted_and_signed_mail)
      assert result.present?
      assert result[0].encrypted? == false
    end
  end

  it 'should call assure public key available when email is signed' do
    GpgMailHelper.expects(:assure_public_key_available).returns(true)
    assert GpgMailHelper.decrypt_if_encrypted(signed_mail)
  end

  it 'should call assure public key available when email needs the key' do
    AppSettings.gpg_mail_verification_required = true
    assert GpgMailHelper.decrypt_if_encrypted(simple_mail).nil?
    AppSettings.gpg_mail_verification_required = false
  end

  it 'Should decrypt an encrypted mail' do
    encrypted = encrypted_mail
    assert encrypted.encrypted?
    result = GpgMailHelper.decrypt_if_encrypted encrypted
    assert result[0].encrypted? == false
  end

  it 'should return nil when the email is badly signed' do
    assert GpgMailHelper.decrypt_if_encrypted(badly_signed_mail).nil?
  end

  it 'should properly identify encryption status' do
      assert GpgMailHelper.decrypt_if_encrypted(simple_mail)[1] == false
      assert GpgMailHelper.decrypt_if_encrypted(signed_mail)[1] == false
      assert GpgMailHelper.decrypt_if_encrypted(encrypted_mail)[1] == true
      assert GpgMailHelper.decrypt_if_encrypted(encrypted_and_signed_mail)[1] == true
  end

  it 'should properly identify signed status' do
      assert GpgMailHelper.decrypt_if_encrypted(simple_mail)[2] == false
      assert GpgMailHelper.decrypt_if_encrypted(signed_mail)[2] == true
      assert GpgMailHelper.decrypt_if_encrypted(encrypted_mail)[2] == false
      assert GpgMailHelper.decrypt_if_encrypted(encrypted_and_signed_mail)[2] == false
  end

end
