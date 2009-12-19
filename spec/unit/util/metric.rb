#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/metric'

describe Puppet::Util::Metric do
    before do
        @metric = Puppet::Util::Metric.new("foo")
        #if we don't retrive it before the test the :rrddir test will
        #fail at after
        @basedir = @metric.basedir
    end

    after do
        FileUtils.rm_rf(@basedir) if File.directory?(@basedir)
    end

    it "should be aliased to Puppet::Metric" do
        Puppet::Util::Metric.should equal(Puppet::Metric)
    end

    [:type, :name, :value, :label, :basedir].each do |name|
        it "should have a #{name} attribute" do
            @metric.should respond_to(name)
            @metric.should respond_to(name.to_s + "=")
        end
    end

    it "should default to the :rrdir as the basedir "do
        Puppet.settings.expects(:value).with(:rrddir).returns "myrrd"
        @metric.basedir.should == "myrrd"
    end

    it "should use any provided basedir" do
        @metric.basedir = "foo"
        @metric.basedir.should == "foo"
    end

    it "should require a name at initialization" do
        lambda { Puppet::Util::Metric.new }.should raise_error(ArgumentError)
    end

    it "should always convert its name to a string" do
        Puppet::Util::Metric.new(:foo).name.should == "foo"
    end

    it "should support a label" do
        Puppet::Util::Metric.new("foo", "mylabel").label.should == "mylabel"
    end

    it "should autogenerate a label if none is provided" do
        Puppet::Util::Metric.new("foo_bar").label.should == "Foo bar"
    end

    it "should have a method for adding values" do
        @metric.should respond_to(:newvalue)
    end

    it "should have a method for returning values" do
        @metric.should respond_to(:values)
    end

    it "should require a name and value for its values" do
        lambda { @metric.newvalue }.should raise_error(ArgumentError)
    end

    it "should support a label for values" do
        @metric.newvalue(:foo, 10, "label")
        @metric.values[0][1].should == "label"
    end

    it "should autogenerate value labels if none is provided" do
        @metric.newvalue("foo_bar", 10)
        @metric.values[0][1].should == "Foo bar"
    end

    it "should return its values sorted by label" do
        @metric.newvalue(:foo, 10, "b")
        @metric.newvalue(:bar, 10, "a")

        @metric.values.should == [[:bar, "a", 10], [:foo, "b", 10]]
    end

    it "should use an array indexer method to retrieve individual values" do
        @metric.newvalue(:foo, 10)
        @metric[:foo].should == 10
    end

    it "should return nil if the named value cannot be found" do
        @metric[:foo].should be_nil
    end

    it "should be able to graph metrics using RRDTool" do
        ensure_rrd_folder
        populate_metric
        @metric.graph
    end

    it "should be able to create a new RRDTool database" do
        ensure_rrd_folder
        add_random_values_to_metric
        @metric.create
        File.exist?(@metric.path).should == true
    end

    it "should be able to store metrics into an RRDTool database" do
        ensure_rrd_folder
        populate_metric
        File.exist?(@metric.path).should == true
    end

    def ensure_rrd_folder()
        #in normal runs puppet does this for us (not sure where)
        FileUtils.mkdir_p(@basedir) unless File.directory?(@basedir)
    end

    def populate_metric()
        time = Time.now.to_i
        time -= 100 * 1800
        200.times {
            @metric = Puppet::Util::Metric.new("foo")
            add_random_values_to_metric
            @metric.store(time)
            time += 1800
        }
    end

    def add_random_values_to_metric()
        @metric.values.clear
        random_params = { :data1 => 10, :data2 => 30, :data3 => 100 }
        random_params.each { | label, maxvalue |
            @metric.newvalue(label, rand(maxvalue))
    }
    end
end
