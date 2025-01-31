vim9script

# Functions related to handling LSP symbol signature help.

var opt = {}
var util = {}
var buf = {}

if has('patch-8.2.4019')
  import './lspoptions.vim' as opt_import
  import './util.vim' as util_import
  import './buffer.vim' as buf_import

  opt.lspOptions = opt_import.lspOptions
  util.WarnMsg = util_import.WarnMsg
  buf.CurbufGetServer = buf_import.CurbufGetServer
else
  import lspOptions from './lspoptions.vim'
  import {WarnMsg} from './util.vim'
  import {CurbufGetServer} from './buffer.vim'

  opt.lspOptions = lspOptions
  util.WarnMsg = WarnMsg
  buf.CurbufGetServer = CurbufGetServer
endif

# close the signature popup window
def CloseSignaturePopup(lspserver: dict<any>)
  lspserver.signaturePopup->popup_close()
  lspserver.signaturePopup = -1
enddef

def CloseCurBufSignaturePopup()
  var lspserver: dict<any> = buf.CurbufGetServer()
  if lspserver->empty()
    return
  endif

  CloseSignaturePopup(lspserver)
enddef

# Initialize the signature triggers for the current buffer
export def SignatureInit(lspserver: dict<any>)
  if !opt.lspOptions.showSignature ||
			!lspserver.caps->has_key('signatureHelpProvider')
    # no support for signature help
    return
  endif

  # map characters that trigger signature help
  for ch in lspserver.caps.signatureHelpProvider.triggerCharacters
    exe 'inoremap <buffer> <silent> ' .. ch .. ' ' .. ch
					.. "<C-R>=LspShowSignature()<CR>"
  endfor
  # close the signature popup when leaving insert mode
  autocmd InsertLeave <buffer> call CloseCurBufSignaturePopup()
enddef

# Display the symbol signature help
export def SignatureDisplay(lspserver: dict<any>, sighelp: dict<any>): void
  if sighelp->empty()
    CloseSignaturePopup(lspserver)
    return
  endif

  if sighelp.signatures->len() <= 0
    util.WarnMsg('No signature help available')
    CloseSignaturePopup(lspserver)
    return
  endif

  var sigidx: number = 0
  if sighelp->has_key('activeSignature')
    sigidx = sighelp.activeSignature
  endif

  var sig: dict<any> = sighelp.signatures[sigidx]
  var text: string = sig.label
  var hllen: number = 0
  var startcol: number = 0
  if sig->has_key('parameters') && sighelp->has_key('activeParameter')
    var params_len = sig.parameters->len()
    if params_len > 0 && sighelp.activeParameter < params_len
      var label: string = sig.parameters[sighelp.activeParameter].label
      hllen = label->len()
      startcol = text->stridx(label)
    endif
  endif
  if opt.lspOptions.echoSignature
    echon "\r\r"
    echon ''
    echon strpart(text, 0, startcol)
    echoh LineNr
    echon strpart(text, startcol, hllen)
    echoh None
    echon strpart(text, startcol + hllen)
  else
    # Close the previous signature popup and open a new one
    lspserver.signaturePopup->popup_close()

    var popupID = text->popup_atcursor({moved: [col('.') - 1, 9999999]})
    var bnum: number = popupID->winbufnr()
    prop_type_add('signature', {bufnr: bnum, highlight: 'LineNr'})
    if hllen > 0
      prop_add(1, startcol + 1, {bufnr: bnum, length: hllen, type: 'signature'})
    endif
    lspserver.signaturePopup = popupID
  endif
enddef

# vim: shiftwidth=2 softtabstop=2
