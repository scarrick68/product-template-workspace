#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../services/install_local_dev_tools"

module Workspace
  module Commands
    # Compatibility shim: prefer Workspace::Services::InstallLocalDevTools.
    class SetupToolsCommand < Workspace::Services::InstallLocalDevTools
    end
  end
end

