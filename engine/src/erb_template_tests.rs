use super::*;

// Native tests authored, UNRUN in the source-only phase. Execute on the same
// guarded stack used in production, including parser destruction.
fn analyze_saved(text: &'static str) -> Value {
    let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    crate::capture::parser_worker("thistle-erb-test",move ||
        analyze("app/views/receipt_mailer/receipt.html.erb",text)).unwrap()
}

#[test]
fn erb_is_inert_and_references_have_original_physical_spans() {
    let text = "<h1>é</h1>\n<%= receipt_heading(@recipient) %>\n<%= render partial: 'receipt_mailer/footer' %>\n<%# @comment_only %><%%= @escaped_only %>";
    let result = analyze_saved(text);
    let references = result["references"].as_array().unwrap();
    let variable = references.iter().find(|r| r["kind"] == "instance_variable").unwrap();
    assert_eq!(variable["name"],"@recipient");
    assert_eq!(variable["span"]["start_line"],2);
    let start = variable["span"]["start_byte"].as_u64().unwrap() as usize;
    let end = variable["span"]["end_byte"].as_u64().unwrap() as usize;
    assert_eq!(&text[start..end],"@recipient");
    assert!(references.iter().any(|r| r["kind"] == "helper_candidate" && r["name"] == "receipt_heading"));
    assert!(references.iter().any(|r| r["kind"] == "partial_candidate" && r["target"] == "receipt_mailer/footer"));
    assert!(!references.iter().any(|r| matches!(r["name"].as_str(),Some("@comment_only"|"@escaped_only"))));
    assert_eq!(result["execution"],"unknown");
}

#[test]
fn dynamic_selection_unclosed_tags_and_unsupported_projection_stay_unknown() {
    let result = analyze_saved("<%= render partial: @selected %>");
    assert!(result["references"].as_array().unwrap().iter().any(|r| r["selection"] == "dynamic_or_unsupported_unknown"));
    for text in ["<%", "<%=", "<% if %>"] {
        assert_eq!(analyze_saved(text)["status"],"unknown");
    }
    assert!(analyze("view.haml","= helper").is_err());
    assert!(analyze("../view.erb","plain").is_err());
}
