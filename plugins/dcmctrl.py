def getDevice(model, module, compiler, helpers):
  return DCMCtrlDevice(model, module, compiler, helpers)

def toGPIO(this, items):
  return 'GPIO' + chr(items+65)

def default_config():
  return {}

class DCMCtrlDevice():
  size = 1
  motorcount = 6
  ctype = 'uint16_t[16]'
  rusttype = 'u8'
  include = ['motors.h'] 
  init_source = ''
  dev_to_mem_source = ''
  mem_to_dev_source = ''
  mem_doc = { 
    "read": [
    ],
    "write": [
    ]
  }

  decl = {
    'c': { 'name': 'motor_t', 'arr': '[6]' },
    'rust': { 'name': '[Motor; 6]', 'decl': """#[repr(C)]
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
    self.module = module
    self.helpers = {'gpio': toGPIO, **helpers}
    self.compiler = compiler
    self.model = model

  def compile(self):
    dev_to_mem_str = """// source for device {{device.name}}
  dc_read_all_{{device.index}}(plc_mem_devices.m{{device.slot}}); 
  """

    for i in range(self.motorcount):
      self.mem_doc['read'].append(
      {
        "byte": (i*4),
        "bit": 0,
        "length": 1,
        "name": "OTW M{}".format(i),
        "desc": "Over-Temperature Error Motor {}".format(i),
        "signed": False
      })
      self.mem_doc['read'].append(
      {
        "byte": (i*4),
        "bit": 1,
        "length": 1,
        "name": "FAULT M{}".format(i),
        "desc": "Fault Motor {}".format(i),
        "signed": False
      })
      self.mem_doc['read'].append(
      {
        "byte": (i*4),
        "bit": 2,
        "length": 1,
        "name": "Timeout M{}".format(i),
        "desc": "Timeout Motor {}".format(i),
        "signed": False
      })
      self.mem_doc['read'].append(
      {
        "byte": (i*4)+1,
        "bit": 0,
        "length": 24,
        "name": "Pos M{}".format(i),
        "desc": "Current Position Motor {}".format(i),
        "signed": False
      })
  
    dev_to_mem_template = self.compiler.compile(dev_to_mem_str)
    self.dev_to_mem_source = dev_to_mem_template(self.module, self.helpers)