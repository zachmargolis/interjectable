require 'spec_helper'

describe Interjectable do
  shared_examples_for "an interjectable class" do
    let(:instance) { klass.new }

    describe "#inject" do
      before do
        klass.inject(:some_dependency) { :service }
      end

      it "adds an instance method getter and setter" do
        instance.some_dependency = 'aaa'
        instance.some_dependency.should == 'aaa' 
      end

      it "lazy-loads the default block" do
        instance.instance_variable_get("@some_dependency").should be_nil
        instance.some_dependency.should == :service
        instance.instance_variable_get("@some_dependency").should_not be_nil
      end

      it "allows transitive dependencies (via instance_eval)" do
        klass.inject(:first_dependency) { second_dependency }
        klass.inject(:second_dependency) { :value }

        instance.first_dependency.should == :value
      end

      it "calls dependency block once, even with a falsy value" do
        count = 0;
        klass.inject(:some_falsy_dependency) { count += 1; nil }

        2.times { instance.some_falsy_dependency.should be_nil }
        count.should == 1
      end

      context "with a dependency on another class" do
        before do
          defined?(SomeOtherClass).should be_false

          klass.inject(:some_other_class) { SomeOtherClass.new }
        end

        it "does not need to load that class (can be stubbed away)" do
          instance.some_other_class = :fake_other_class

          instance.some_other_class.should == :fake_other_class
        end
      end
    end

    describe "#inject_static" do
      let(:other_instance) { klass.new }

      before do
        klass.inject_static(:static_dependency) { :some_value }
      end

      it "adds an instance method and setter" do
        instance.static_dependency = 'aaa'
        instance.static_dependency.should == 'aaa'
      end

      it "shares a value across all instances of a class" do
        instance.static_dependency = 'bbb'
        other_instance.static_dependency.should == 'bbb'
      end

      it "calls its dependency block once across all instances" do
        count = 0;
        klass.inject_static(:falsy_static_dependency) { count += 1; nil }

        instance.falsy_static_dependency.should be_nil
        other_instance.falsy_static_dependency.should be_nil

        count.should == 1
      end

      context "with a subclas" do
        let(:subclass) { Class.new(klass) }
        let(:subclass_instance) { subclass.new }

        it "shares its values with its superclass" do
          instance.static_dependency = 'ccc'
          subclass_instance.static_dependency.should == 'ccc'
        end
      end
    end
  end

  context "when extended" do
    let(:klass) { Class.new { extend Interjectable } }

    it_should_behave_like "an interjectable class"
  end

  context "when included" do
    let(:klass) { Class.new { extend Interjectable } }

    it_should_behave_like "an interjectable class"
  end
end
