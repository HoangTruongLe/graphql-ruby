# frozen_string_literal: true
require "spec_helper"

describe GraphQL::Execution::Interpreter do
  module InterpreterTest
    class Query < GraphQL::Schema::Object
      field :card, "InterpreterTest::Card", null: true do
        argument :name, String, required: true
      end

      def card(name:)
        CARDS.find { |c| c.name == name }
      end

      field :expansion, "InterpreterTest::Expansion", null: true do
        argument :sym, String, required: true
      end

      def expansion(sym:)
        EXPANSIONS.find { |e| e.sym == sym }
      end

      CARDS = [
        OpenStruct.new(name: "Dark Confidant", colors: ["BLACK"], expansion_sym: "RAV"),
      ]

      EXPANSIONS = [
        OpenStruct.new(name: "Ravnica, City of Guilds", sym: "RAV"),
      ]
    end

    class Expansion < GraphQL::Schema::Object
      field :sym, String, null: false
      field :name, String, null: false
      field :cards, ["InterpreterTest::Card"], null: false

      def cards
        Query::CARDS.select { |c| c.expansion_sym == @object.sym }
      end
    end

    class Card < GraphQL::Schema::Object
      field :name, String, null: false
      field :colors, "[InterpreterTest::Color]", null: false
      field :expansion, Expansion, null: false

      def expansion
        Query::EXPANSIONS.find { |e| e.sym == @object.expansion_sym }
      end
    end

    class Color < GraphQL::Schema::Enum
      value "WHITE"
      value "BLUE"
      value "BLACK"
      value "RED"
      value "GREEN"
    end

    class Schema < GraphQL::Schema
      query(Query)
    end
    # TODO encapsulate this in `use` ?
    Schema.graphql_definition.query_execution_strategy = GraphQL::Execution::Interpreter
    # Don't want this wrapping automatically
    Schema.instrumenters[:field].delete(GraphQL::Schema::Member::Instrumentation)
    Schema.instrumenters[:query].delete(GraphQL::Schema::Member::Instrumentation)
  end

  it "runs a query" do
    query_string = <<-GRAPHQL
    query($expansion: String!){
      card(name: "Dark Confidant") {
        colors
        expansion {
          name
        }
      }
      expansion(sym: $expansion) {
        cards {
          name
        }
      }
    }
    GRAPHQL

    result = result = InterpreterTest::Schema.execute(query_string, variables: { expansion: "RAV" })
    pp result
    assert_equal ["BLACK"], result["data"]["card"]["colors"]
    assert_equal "Ravnica, City of Guilds", result["data"]["card"]["expansion"]["name"]
    assert_equal [{"name" => "Dark Confidant"}], result["data"]["expansion"]["cards"]
  end
end
