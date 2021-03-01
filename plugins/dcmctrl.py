def getDevice(model, module, compiler, helpers):
  return DCMCtrlDevice(model, module, compiler, helpers)

def toGPIO(this, items):
  return 'GPIO' + chr(items+65)

def default_config():
  return {}

class DCMCtrlDevice():
  motor_count = 6
  size = 1
  ctype = 'uint16_t[16]'
  rusttype = 'u8'
  include = ['motors.h'] 
  init_source = ''
  dev_to_mem_source = ''
  mem_to_dev_source = ''
  mem_doc = { 
    "read": [
      {
      }
    ],
    "write": [
      {
      }
    ]
  }

  decl = {
    'c': { 'name': 'motor_t', 'arr': '[6]' },
    'rust': { 'name': '[Motor; 6]', 'decl': """#[repr(C, packed)]
pub struct Motor { 
  pub flags: u8,
  pub position: u32,
}
""" }
  }

  module = None
  model = None
  compiler = None
  helpers = None 
  
  def __init__(self, model, module, compiler, helpers):
    self.size = 1
    self.motor_count = 6
    self.module = module
    self.helpers = {'gpio': toGPIO, **helpers}
    self.compiler = compiler
    self.model = model

  def compile(self):
    dev_to_mem_str = """// source for device {{device.name}}
  dc_read_all_{{device.index}}(plc_mem_devices.m{{device.slot}}); 
  """

    for n in range(self.motor_count)

    dev_to_mem_template = self.compiler.compile(dev_to_mem_str)
    self.dev_to_mem_source = dev_to_mem_template(self.module, self.helpers)