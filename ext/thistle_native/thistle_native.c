#include <ruby.h>
#include <ruby/thread.h>
#include <stdint.h>
#include <string.h>

extern char *thistle_request(const uint8_t *input, size_t length);
extern void thistle_response_free(char *response);

struct thistle_call { char *input; size_t length; char *output; };

static void *thistle_without_gvl(void *opaque) {
  struct thistle_call *call = (struct thistle_call *)opaque;
  call->output = thistle_request((const uint8_t *)call->input, call->length);
  return NULL;
}

static VALUE thistle_call_body(VALUE opaque) {
  struct thistle_call *call = (struct thistle_call *)opaque;
  rb_thread_call_without_gvl(thistle_without_gvl, call, NULL, NULL);
  if (!call->output) rb_raise(rb_eRuntimeError, "Native engine returned no response");
  return rb_utf8_str_new_cstr(call->output);
}

static VALUE thistle_call_cleanup(VALUE opaque) {
  struct thistle_call *call = (struct thistle_call *)opaque;
  if (call->output) thistle_response_free(call->output);
  xfree(call->input);
  return Qnil;
}

static VALUE thistle_raw_call(VALUE self, VALUE input) {
  (void)self;
  StringValue(input);
  long length = RSTRING_LEN(input);
  if (length < 0 || (unsigned long)length > 128UL * 1024UL * 1024UL)
    rb_raise(rb_eArgError, "Native request exceeds 128 MiB");
  struct thistle_call call = { NULL, (size_t)length, NULL };
  call.input = ALLOC_N(char, length ? length : 1);
  if (length) memcpy(call.input, RSTRING_PTR(input), (size_t)length);
  return rb_ensure(thistle_call_body, (VALUE)&call, thistle_call_cleanup, (VALUE)&call);
}

void Init_thistle_native(void) {
  VALUE thistle = rb_define_module("Thistle");
  VALUE native = rb_define_module_under(thistle, "Native");
  rb_define_singleton_method(native, "request_raw", thistle_raw_call, 1);
}
