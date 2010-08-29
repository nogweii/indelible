require 'lib/simplenote'
require 'pp'

describe ZenNote::Index do
  BASE_INDEX = { 'created' => Time.now, 'last_synced' => nil,
    'count' => 2, 'notes' => {
      'c5dda1' => { 'modified' => '2010-10-10 10:10:10',
                    'path' => '/tmp/eitanoisa.txt',
                    'status' => 'synced' },
      '42ffa1' => { 'modified' => '2009-12-10 17:00:02',
                    'path' => '/tmp/bundinha linda.txt',
                    'status' => 'synced' }
    },
    'hashes' => {}, 'paths' => {}
  }

  before :each do
    open(File.join('/tmp', '.zennote'), 'w') { |f| f << BASE_INDEX.to_json }
    @index = ZenNote::Index.new('/tmp')
  end

  it 'should retrieve notes' do
    @index.retrieve_note('c5dda1').should == BASE_INDEX['notes']['c5dda1']
    @index.retrieve_note('42ffa1').should == BASE_INDEX['notes']['42ffa1']
  end

  it 'should purge note' do
    @index.purge_note('c5dda1').should be_nil
    @index.retrieve_note('c5dda1').should be_nil
  end

  it 'should store and retrieve note' do
    Digest::MD5.should_receive(:hexdigest).and_return('sfjlsafjksajkfqw90324')
    File.should_receive(:open).and_return(Struct.new(:read).new(''))
    @index.store_note('ee8fd1', '2010-08-24 10:32:00', '/tmp/gamei.txt').should == nil
    @index.retrieve_note('ee8fd1').should == { 'modified' => '2010-08-24 10:32:00', 'path' => '/tmp/gamei.txt', 'status' => 'synced' }
  end

  it 'should remove note from index' do
    @index.remove_note('c5dda1').should be_nil
    @index.retrieve_note('c5dda1')['status'].should == 'local_delete'
  end

  it 'should return "c5dda1" as what should be removed remotely, "42ffa1" as what should be removed locally, "ee8fd1" to be retrieved"' do
    sn_data = [{ 'key' => 'c5dda1',
                 'modify' => '2010-10-10 10:10:10', 'deleted' => false },
               { 'key' => 'ee8fd1', 'modify' => '2010-08-24 10:32:00',
                 'deleted' => false },
               { 'key' => '42ffa1', 'modified' => '2009-12-10 17:00:02',
                 'deleted' => true }]

    @index.remove_note('c5dda1').should be_nil
    diff = @index.diff sn_data
    diff[:retrieve].should == ['ee8fd1']
    diff[:remove_local].should == ['42ffa1']
    diff[:remove_remote].should == ['c5dda1']
    diff[:push].should == []
  end
end

