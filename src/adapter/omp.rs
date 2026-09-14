use serde_json::Value;

use crate::event::{AgentEvent, AgentEventKind, EventAdapter};
use crate::tmux::OMP_AGENT;
use crate::tool_name::CanonicalTool;

use super::{HookRegistration, json_str, json_value_or_null, optional_str};

pub struct OmpAdapter;

fn normalize_tool_name(raw: &str) -> String {
    let canonical = match raw {
        "bash" => CanonicalTool::Bash,
        "read" => CanonicalTool::Read,
        "write" => CanonicalTool::Write,
        "edit" => CanonicalTool::Edit,
        "glob" => CanonicalTool::Glob,
        "grep" => CanonicalTool::Grep,
        "web_search" => CanonicalTool::WebSearch,
        "task" => CanonicalTool::Agent,
        "lsp" => CanonicalTool::Lsp,
        "todo" => CanonicalTool::TodoWrite,
        other => return other.to_owned(),
    };
    canonical.as_str().to_owned()
}

fn normalize_tool_input(tool_name: &str, input: Value) -> Value {
    let Value::Object(mut map) = input else {
        return input;
    };
    if matches!(tool_name, "Read" | "Write" | "Edit")
        && !map.contains_key("file_path")
        && let Some(value) = map.get("path").cloned()
    {
        map.insert("file_path".to_owned(), value);
    }
    Value::Object(map)
}

impl OmpAdapter {
    /// OMP discovers this extension from `.omp/extensions/`; unlike the
    /// JSON-hook agents, its bridge subscribes to the typed lifecycle bus.
    pub const HOOK_REGISTRATIONS: &'static [HookRegistration] = &[
        HookRegistration {
            trigger: "session_start",
            matcher: None,
            kind: AgentEventKind::SessionStart,
        },
        HookRegistration {
            trigger: "session_shutdown",
            matcher: None,
            kind: AgentEventKind::SessionEnd,
        },
        HookRegistration {
            trigger: "input",
            matcher: None,
            kind: AgentEventKind::UserPromptSubmit,
        },
        HookRegistration {
            trigger: "tool_result",
            matcher: None,
            kind: AgentEventKind::ActivityLog,
        },
        HookRegistration {
            trigger: "agent_end",
            matcher: None,
            kind: AgentEventKind::Stop,
        },
    ];
}

impl EventAdapter for OmpAdapter {
    fn parse(&self, event_name: &str, input: &Value) -> Option<AgentEvent> {
        match event_name {
            "session-start" => Some(AgentEvent::SessionStart {
                agent: OMP_AGENT.into(),
                cwd: json_str(input, "cwd").into(),
                permission_mode: String::new(),
                source: json_str(input, "source").into(),
                worktree: None,
                agent_id: None,
                session_id: optional_str(input, "session_id"),
            }),
            "session-end" => Some(AgentEvent::SessionEnd {
                end_reason: json_str(input, "reason").into(),
            }),
            "user-prompt-submit" => Some(AgentEvent::UserPromptSubmit {
                agent: OMP_AGENT.into(),
                cwd: json_str(input, "cwd").into(),
                permission_mode: String::new(),
                prompt: json_str(input, "prompt").into(),
                worktree: None,
                agent_id: None,
                session_id: optional_str(input, "session_id"),
            }),
            "stop" => Some(AgentEvent::Stop {
                agent: OMP_AGENT.into(),
                cwd: json_str(input, "cwd").into(),
                permission_mode: String::new(),
                last_message: json_str(input, "last_message").into(),
                response: None,
                worktree: None,
                agent_id: None,
                session_id: optional_str(input, "session_id"),
            }),
            "activity-log" => {
                let raw_name = json_str(input, "tool_name");
                if raw_name.is_empty() {
                    return None;
                }
                let tool_name = normalize_tool_name(raw_name);
                let tool_input =
                    normalize_tool_input(&tool_name, json_value_or_null(input, "tool_input"));
                Some(AgentEvent::ActivityLog {
                    tool_name,
                    tool_input,
                    tool_response: json_value_or_null(input, "tool_response"),
                })
            }
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn session_start_identifies_omp() {
        let event = OmpAdapter
            .parse(
                "session-start",
                &json!({"cwd": "/tmp", "source": "startup"}),
            )
            .unwrap();
        assert_eq!(
            event,
            AgentEvent::SessionStart {
                agent: OMP_AGENT.into(),
                cwd: "/tmp".into(),
                permission_mode: String::new(),
                source: "startup".into(),
                worktree: None,
                agent_id: None,
                session_id: None,
            }
        );
    }

    #[test]
    fn activity_log_normalizes_omp_bash() {
        let event = OmpAdapter
            .parse(
                "activity-log",
                &json!({"tool_name": "bash", "tool_input": {"command": "cargo test"}}),
            )
            .unwrap();
        match event {
            AgentEvent::ActivityLog {
                tool_name,
                tool_input,
                ..
            } => {
                assert_eq!(tool_name, "Bash");
                assert_eq!(tool_input["command"], "cargo test");
            }
            other => panic!("expected ActivityLog, got {other:?}"),
        }
    }
    #[test]
    fn hook_registrations_match_parser() {
        super::super::assert_table_drift_free(OMP_AGENT, OmpAdapter::HOOK_REGISTRATIONS);
    }
}
