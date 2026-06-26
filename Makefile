SKILL_NAME  := neuron
SKILL_DIR   := $(CURDIR)/skill
REPO_DIR    := $(CURDIR)
CONFIG_DIR  := $(HOME)/.agents-neuron

AGENTS_SKILLS := $(HOME)/.agents/skills
CLAUDE_SKILLS := $(HOME)/.claude/skills

.PHONY: install setup uninstall test

test:
	@fail=0; \
	for t in "$(REPO_DIR)"/tests/test-*.sh; do \
		[ -f "$$t" ] || continue; \
		echo "==> $$t"; \
		bash "$$t" || fail=1; \
	done; \
	exit $$fail

install: setup
	@echo ""
	@echo "Installing skill symlinks..."
	@mkdir -p "$(AGENTS_SKILLS)"
	@mkdir -p "$(CLAUDE_SKILLS)"
	@for target in "$(AGENTS_SKILLS)/$(SKILL_NAME)" "$(CLAUDE_SKILLS)/$(SKILL_NAME)"; do \
		real=$$(realpath "$$target" 2>/dev/null || echo ""); \
		if [ "$$real" = "$(SKILL_DIR)" ]; then \
			echo "  already linked: $$target"; \
		else \
			ln -sfn "$(SKILL_DIR)" "$$target" && echo "  linked: $$target -> $(SKILL_DIR)"; \
		fi; \
	done
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo " NEXT STEP — Generate your identity filter"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo " Paste the prompt from URL below into your LLM (ex: ChatGPT or any LLM that knows you):"
	@echo ""
	@echo "https://github.com/glonlas/neuron/blob/main/docs/configuration.md#generating-your-filter-identitymd"
	@echo ""
	@echo " Then save the output to:"
	@echo "   $(CONFIG_DIR)/filter-identity.md"
	@echo ""
	@echo " Finally, edit your vault path and run neuron bootstrap:"
	@echo "   1. edit $(CONFIG_DIR)/config.yaml  (set vault_path)"
	@echo "   2. neuron bootstrap                 (in Claude Code)"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

setup:
	@echo "Setting up personal config at $(CONFIG_DIR)..."
	@mkdir -p "$(CONFIG_DIR)"
	@if [ ! -f "$(CONFIG_DIR)/config.yaml" ]; then \
		cp "$(REPO_DIR)/schema/config.example.yaml" "$(CONFIG_DIR)/config.yaml" && \
		echo "  created: $(CONFIG_DIR)/config.yaml"; \
	else \
		echo "  exists:  $(CONFIG_DIR)/config.yaml"; \
	fi
	@if [ ! -f "$(CONFIG_DIR)/filter-identity.md" ]; then \
		cp "$(REPO_DIR)/schema/filter-identity.example.md" "$(CONFIG_DIR)/filter-identity.md" && \
		echo "  created: $(CONFIG_DIR)/filter-identity.md"; \
	else \
		echo "  exists:  $(CONFIG_DIR)/filter-identity.md"; \
	fi
	@if [ ! -f "$(CONFIG_DIR)/query-log.md" ]; then \
		cp "$(REPO_DIR)/schema/query-log.example.md" "$(CONFIG_DIR)/query-log.md" && \
		echo "  created: $(CONFIG_DIR)/query-log.md"; \
	else \
		echo "  exists:  $(CONFIG_DIR)/query-log.md"; \
	fi

uninstall:
	@echo "Removing skill symlinks..."
	@removed=0; \
	for target in "$(AGENTS_SKILLS)/$(SKILL_NAME)" "$(CLAUDE_SKILLS)/$(SKILL_NAME)"; do \
		if [ -L "$$target" ]; then \
			rm "$$target" && echo "  removed: $$target" && removed=1; \
		fi; \
	done; \
	[ "$$removed" = "0" ] && echo "  no symlinks found" || true
	@echo ""
	@printf "Remove personal config at $(CONFIG_DIR)? [y/N] "; \
	read ans; \
	case "$$ans" in \
		[Yy]*) rm -rf "$(CONFIG_DIR)" && echo "  removed: $(CONFIG_DIR)";; \
		*)     echo "  kept: $(CONFIG_DIR)";; \
	esac
