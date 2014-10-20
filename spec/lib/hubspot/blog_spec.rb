require 'spec_helper'
require 'timecop'

describe Hubspot do
  let(:example_blog_hash) do
    VCR.use_cassette("blog_list", record: :none) do
      url = Hubspot::Utils.generate_url(Hubspot::Blog::BLOG_LIST_PATH)
      resp = HTTParty.get(url, format: :json)
      resp.parsed_response["objects"].first
    end
  end

  before do
    Hubspot.configure(hapikey: "demo")
    Timecop.freeze(Time.local(2012, 'Oct', 10))
  end

  after do
    Timecop.return
  end

  describe Hubspot::Blog do

    describe ".list" do
      cassette "blog_list"
      let(:blog_list) { Hubspot::Blog.list }

      it "should have a list of blogs" do
        blog_list.count.should be(1)
      end
    end

    describe ".find_by_id" do
      cassette "blog_list"

      it "should have a list of blogs" do
        blog = Hubspot::Blog.find_by_id(351076997)
        blog["id"].should eq(351076997)
      end
    end

    describe "#initialize" do
      subject{ Hubspot::Blog.new(example_blog_hash) }
      its(["name"]) { should == "API Demonstration Blog" }
      its(["id"])   { should == 351076997 }
    end

    describe "#posts" do
      cassette "one_month_blog_posts_filter_state"
      let(:blog) { Hubspot::Blog.new(example_blog_hash) }

      describe "can be filtered by state" do

        it "should filter the posts to published by default" do
          # in our date range they are all draft, hence no items
          blog.posts.length.should be(13)
        end

        it "should validate the state is a valid one" do
          expect { blog.posts('invalid') }.to raise_error(Hubspot::Blog::InvalidParams)
        end

        it "should allow draft posts if specified" do
          # in our date range they are all draft, hence no item
          blog.posts({ state: false }).length.should be > 0
        end
      end

      describe "can be ordered" do
        it "created at descending is default" do
          # in our date range they are all draft, hence no item
          created_timestamps = blog.posts.map { |post| post['created'] }
          expect(created_timestamps.sort.reverse).to eq(created_timestamps)
        end

        it "by created ascending" do
          # in our date range they are all draft, hence no item
          created_timestamps = blog.posts({order_by: '+created'}).map { |post| post['created'] }
          expect(created_timestamps.sort).to eq(created_timestamps)
        end
      end

      it "can set a page size" do
        blog.posts({limit: 10}).length.should be(10)
      end
    end
  end

  describe Hubspot::BlogPost do
    let(:example_blog_post) do
      VCR.use_cassette("one_month_blog_posts_filter_state", record: :none) do
        blog = Hubspot::Blog.new(example_blog_hash)
        blog.posts.first
      end
    end

    it "should have a created_at value specific method" do
      expect(example_blog_post.created_at).to eq(Time.at(example_blog_post['created'] / 1000))
    end
  end
end
