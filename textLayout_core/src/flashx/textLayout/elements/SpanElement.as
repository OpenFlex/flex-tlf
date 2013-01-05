////////////////////////////////////////////////////////////////////////////////
//
//  Licensed to the Apache Software Foundation (ASF) under one or more
//  contributor license agreements.  See the NOTICE file distributed with
//  this work for additional information regarding copyright ownership.
//  The ASF licenses this file to You under the Apache License, Version 2.0
//  (the "License"); you may not use this file except in compliance with
//  the License.  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////
package flashx.textLayout.elements
{
	import flash.text.engine.GroupElement;
	import flash.text.engine.TextElement;
	import flash.utils.getQualifiedClassName;
	
	import flashx.textLayout.container.ContainerController;
	import flashx.textLayout.debug.Debugging;
	import flashx.textLayout.debug.assert;
	import flashx.textLayout.events.ModelChange;
	import flashx.textLayout.formats.FormatValue;
	import flashx.textLayout.formats.ITextLayoutFormat;
	import flashx.textLayout.formats.TextLayoutFormat;
	import flashx.textLayout.formats.TextLayoutFormatValueHolder;
	import flashx.textLayout.formats.WhiteSpaceCollapse;
	import flashx.textLayout.property.Property;
	import flashx.textLayout.tlf_internal;
	import flashx.textLayout.utils.CharacterUtil;
	
	use namespace tlf_internal;
			
	[DefaultProperty("mxmlChildren")]
	
	/** 
	* The SpanElement class represents a run of text that has a single set of formatting attributes applied. SpanElement 
	* objects contain the text in a paragraph. A simple paragraph (ParagraphElement) includes one or more SpanElement objects. 
	*
	* <p>A ParagraphElement will have a single SpanElement object if all the text in the paragraph shares the same set of 
	* attributes. It has multiple SpanElement objects if the text in the paragraph has multiple formats.</p>
	*
	* @playerversion Flash 10
	* @playerversion AIR 1.5
	* @langversion 3.0
	*
	* @includeExample examples/SpanElementExample.as -noswf
	*
	* @see FlowElement
	* @see ParagraphElement
	* @see TextFlow
     	*/
     	
	public class SpanElement extends FlowLeafElement
	{	
		/** @private */
		tlf_internal static const kParagraphTerminator:String = '\u2029';
		
		/** Constructor - creates a SpanElement object to hold a run of text in a paragraph.
		*
		* @playerversion Flash 10
		* @playerversion AIR 1.5
	 	* @langversion 3.0
	 	*/
	 	
		public function SpanElement():void
		{
			super();
		}
		
		/** @private */
		override tlf_internal function createContentElement():void
		{
			if (_blockElement)
				return;
			
			computedFormat;	// BEFORE creating the element
			_blockElement = new TextElement(null,null);			
			CONFIG::debug { Debugging.traceFTECall(_blockElement,null,"new TextElement",null,null); }
			TextElement(_blockElement).replaceText(0, 0, _text);
			CONFIG::debug { Debugging.traceFTECall(null,_blockElement,"replaceText",0,0,_text); }
			_text = null;
			super.createContentElement();
		}
		/** @private */
		override tlf_internal function releaseContentElement():void
		{
			if (_blockElement == null || !canReleaseContentElement())
				return;
			
			CONFIG::debug { assert(_text == null, "_text already has content -- out of date?");	}
			_text = _blockElement.rawText;
			super.releaseContentElement();
		}
		
		/** @private */
		private function getTextElement():TextElement
		{ return TextElement(_blockElement); }
		
		/** @private */
		public override function shallowCopy(startPos:int = 0, endPos:int = -1):FlowElement
		{
			if (endPos == -1)
				endPos = textLength;
				
			// Note to callers: If you are calling this function outside a try/catch, do ensure that the 
			// state of the model is coherent before the call.
			var retFlow:SpanElement = super.shallowCopy(startPos, endPos) as SpanElement;
						
			var startSpan:int = 0;
			var endSpan:int = startSpan + textLength;
			
			var leafElStartPos:int = startSpan >= startPos ? startSpan : startPos;
			var leafElEndPos:int =  endSpan < endPos ? endSpan : endPos;
			if (leafElEndPos == textLength && hasParagraphTerminator)
				--leafElEndPos;
				
			if (leafElStartPos > leafElEndPos)
				throw RangeError(GlobalSettings.resourceStringFunction("badShallowCopyRange"));
			
			var spanText:String = _blockElement ? _blockElement.rawText : _text;
			if (((leafElStartPos != endSpan) && CharacterUtil.isLowSurrogate(spanText.charCodeAt(leafElStartPos))) ||
				((leafElEndPos != 0) && CharacterUtil.isHighSurrogate(spanText.charCodeAt(leafElEndPos-1))))
					throw RangeError(GlobalSettings.resourceStringFunction("badSurrogatePairCopy"));
			
			retFlow.replaceText(0, retFlow.textLength,  String(spanText).substring(leafElStartPos, leafElEndPos));
			
			return retFlow;
		}	
	
		/** @private */
		override protected function get abstract():Boolean
		{
			return false;
		}		

		/** @private */
		public override function get text():String
		{
			// Get the text from the blockElement is there is one, otherwise grab it from the text property
			var textValue:String = _blockElement ? _blockElement.rawText : _text;
			
			// test textLength cause this is a property and the debugger may run this calculation in intermediate states
			if (textLength && hasParagraphTerminator)
				return textValue.substr(0,textLength-1);
				
			return textValue != null ? textValue : "";
		}
		/** 
		 * Receives the String of text that this SpanElement object holds.
		 *
		 * <p>The text of a span does not include the carriage return (CR) at the end of the paragraph
		 * but it is included in the value of <code>textLength</code>.</p>
		 *
		 * @playerversion Flash 10
		 * @playerversion AIR 1.5
	 	 * @langversion 3.0
	 	 */
	 	
	 	public function set text(textValue:String):void
		{
			//original code stripped breaking and tab characters.  new code moved to collapseWhitevar newLineTabPattern:RegExp = /[\n\r\t]/g;
			replaceText(0,textLength, textValue); 
		} 
		
		/** @private */
		public override function getText(relativeStart:int=0, relativeEnd:int=-1, paragraphSeparator:String="\n"):String
		{
			// Get the text from the blockElement is there is one, otherwise grab it from the text property
			var textValue:String = _blockElement ? _blockElement.rawText : _text;

			if (textLength && relativeEnd == textLength && hasParagraphTerminator)
				--relativeEnd;		// don't include terminator
			return textValue ? textValue.substring(relativeStart, relativeEnd) : "";
		}

		[RichTextContent]
		/** 
		 * Sets text based on content within span tags; always deletes existing children.
		 * This property is intended for use during mxml compiled import. When TLF markup elements have other
		 * TLF markup elements as children, the children are assigned to this property.
		 *
		 * @throws TypeError if array element is not a SpecialCharacterElement or a String
		 * @param array - an array of elements within span tags. Each element of array must be a SpecialCharacterElement or a String.
		 *
		 * @playerversion Flash 10
		 * @playerversion AIR 1.5
	 	 * @langversion 3.0
	 	 */
		public function get mxmlChildren():Array
		{
			return [ text ];
		}
		public function set mxmlChildren(array:Array):void
		{
			/* NOTE: all FlowElement implementers and overrides of mxmlChildren must specify [RichTextContent] metadata */

			var str:String = new String();
			for each (var elem:Object in array)
			{
				if (elem is String)
					str += elem as String;
				else if (elem is Number)	// TODO: remove the Number else if when we can test with the most recent compilers.  The [RichTextContent] metadata fixes the issue
					str += elem.toString();
				else if (elem is BreakElement)
					str += String.fromCharCode(0x2028);
				else if (elem is TabElement)
				{
					// Add a placeholder (from Unicode private use area) instead of '\t' because the latter is 
					// stripped during white space collapse. After white space collapse, we will change the placeholder
					// to '\t' 
					str += String.fromCharCode(0xE000); 
				}	
				else if (elem != null)
					throw new TypeError(GlobalSettings.resourceStringFunction("badMXMLChildrenArgument",[ getQualifiedClassName(elem) ]));
					
			}
			replaceText(0,textLength, str); 
		}
		
		
		/** 
		 * Specifies whether this SpanElement object terminates the paragraph. The SpanElement object that terminates a 
		 * paragraph has an extra, hidden character at the end. This character is added automatically by the component and is
		 * included in the value of the <code>textLength</code> property.
		 * 
		 * @private */
		 
		tlf_internal function get hasParagraphTerminator():Boolean
		{
			var p:ParagraphElement = getParagraph();
			return (p && p.getLastLeaf() == this); 
		}
		
		/** @private */
		CONFIG::debug tlf_internal function verifyParagraphTerminator():void
		{
			var str:String = _blockElement ? _blockElement.rawText : _text;
			assert(str && str.length && str.charAt(str.length-1) == SpanElement.kParagraphTerminator,
				"attempting to remove para terminator when it doesn't exist");
		}
		
		
		/**
		 * Makes a shallow copy of this SpanElement between 2 character positions
		 * and returns it as a FlowElement.  Unlike deepCopy, shallowCopy does
		 * not copy any of the children of this SpanElement.
		 * 
		 */
		 
		 // If I have a sequence of different sorts of spaces (e.g., en quad, hair space), would I want them converted down to one space? Probably not.
		 // For now, u0020 is the only space character we consider for eliminating duplicates, though u00A0 (non-breaking space) is potentially eligible. 
		 private static const _dblSpacePattern:RegExp = /[\u0020]{2,}/g;
		 // Tab, line feed, and carriage return
		 private static const _newLineTabPattern:RegExp = /[\u0009\u000a\u000d]/g;
		 private static const _tabPlaceholderPattern:RegExp = /\uE000/g;
		 
		 // static private const anyPrintChar:RegExp = /[^\s]/g;
		 // Consider only tab, line feed, carriage return, and space as characters used for pretty-printing. 
		 // While debatable, this is consistent with what CSS does. 
		 static private const anyPrintChar:RegExp = /[^\u0009\u000a\u000d\u0020]/g; 

		 /** @private */
		tlf_internal override function applyWhiteSpaceCollapse(collapse:String):void
		{
			var ffc:TextLayoutFormatValueHolder = this.formatForCascade;
			var wsc:* = ffc ? ffc.whiteSpaceCollapse : undefined;
			if (wsc !== undefined && wsc != FormatValue.INHERIT)
				collapse = wsc;
				
			var tempTxt:String = text;
				
			if (!collapse /* null == default value == COLLAPSE */ || collapse == WhiteSpaceCollapse.COLLAPSE)
			{
				// The span was added automatically when a String was passed to replaceChildren.
				// If it contains only whitespace, we remove the text.
				if (impliedElement && parent != null)
				{
					// var matchArray:Array = tempTxt.search(anyPrintChar);
					if (tempTxt.search(anyPrintChar) == -1)
					{
						parent.removeChild(this);
						return;
					}
				}
				
				// For now, replace the newlines and tabs inside the element with a space.
				// This is necessary for support of compiled mxml files that have newlines and tabs, because
				// these are most likely not intended to be part of the text content, but only there so the
				// text can be conveniently edited in the mxml file. Later on we need to add standalone elements
				// for <br/> and <tab/>. Note that tab character is not supported in HTML.	
				tempTxt = tempTxt.replace(_newLineTabPattern, " ");

				// Replace sequences of 2 or more whitespace characters with single space
				tempTxt = tempTxt.replace(_dblSpacePattern, " ");
				}
			
			// Replace tab placeholders (used for tabs that are expected to survive whitespace collapse) with '\t'
			replaceText(0, textLength, tempTxt.replace(_tabPlaceholderPattern, '\t'));

			super.applyWhiteSpaceCollapse(collapse);
		}
		
		/** 
		 * Updates the text in text span based on the specified start and end positions. To insert text, set the end position
		 * equal to the start position. To append text to the existing text in the span, set the start position and the
		 * end position equal to the length of the existing text.
		 *
		 * <p>The replaced text includes the start character and up to but not including the end character.</p>
		 * 
		 *  @param relativeStartPosition The index position of the beginning of the text to be replaced, 
		 *   relative to the start of the span. The first character in the span is at position 0.
		 *  @param relativeEndPosition The index one position after the last character of the text to be replaced, 
		 *   relative to the start of the span. Set this value equal to <code>relativeStartPos</code>
		 *   for an insert. 
		 *  @param textValue The replacement text or the text to add, as the case may be.
		 * 
		 *  @throws RangeError The <code>relativeStartPosition</code> or <code>relativeEndPosition</code> specified is out of 
		 * range or a surrogate pair is being split as a result of the replace.
		 *
		 * @playerversion Flash 10
		 * @playerversion AIR 1.5
	 	 * @langversion 3.0
	 	 *
	 	 * @includeExample examples/SpanElement_replaceTextExample.as -noswf
		 */
		 
		public function replaceText(relativeStartPosition:int, relativeEndPosition:int, textValue:String):void
		{
			// Note to callers: If you are calling this function outside a try/catch, do ensure that the 
			// state of the model is coherent before the call.
			if (relativeStartPosition < 0 || relativeEndPosition > textLength || relativeEndPosition < relativeStartPosition)
				throw RangeError(GlobalSettings.resourceStringFunction("invalidReplaceTextPositions"));	


			var spanText:String = _blockElement ? _blockElement.rawText : _text;
			if ((relativeStartPosition != 0 && relativeStartPosition != textLength && CharacterUtil.isLowSurrogate(spanText.charCodeAt(relativeStartPosition))) ||
				(relativeEndPosition != 0 && relativeEndPosition != textLength && CharacterUtil.isHighSurrogate(spanText.charCodeAt(relativeEndPosition-1))))
					throw RangeError (GlobalSettings.resourceStringFunction("invalidSurrogatePairSplit"));
				
			if (hasParagraphTerminator)
			{
				CONFIG::debug { assert(textLength > 0,"invalid span"); }
				if (relativeStartPosition == textLength)
					relativeStartPosition--;
				if (relativeEndPosition == textLength)
					relativeEndPosition--;
			}
			
			if (relativeEndPosition != relativeStartPosition)
				modelChanged(ModelChange.TEXT_DELETED,relativeStartPosition,relativeEndPosition-relativeStartPosition);
			
			replaceTextInternal(relativeStartPosition,relativeEndPosition,textValue);
			
			if (textValue && textValue.length)
				modelChanged(ModelChange.TEXT_INSERTED,relativeStartPosition,textValue.length);
		}
		private function replaceTextInternal(startPos:int, endPos:int, textValue:String):void
		{			
			var textValueLength:int = textValue == null ? 0 : textValue.length;
			var deleteTotal:int = endPos-startPos;
			var deltaChars:int =  textValueLength - deleteTotal;
			if (_blockElement)
			{
				TextElement(_blockElement).replaceText(startPos,endPos,textValue);
				CONFIG::debug { Debugging.traceFTECall(null,TextElement(_blockElement),"replaceText",startPos,endPos,textValue); }
			}
			else if (_text)
			{
				if (textValue)
					_text = _text.slice(0, startPos) + textValue + _text.slice(endPos, _text.length);
				else
					_text = _text.slice(0, startPos) + _text.slice(endPos, _text.length);
			}
			else
				_text = textValue;
			
			if (deltaChars != 0)
			{
				updateLengths(getAbsoluteStart() + startPos, deltaChars, true);
				deleteContainerText(endPos,deleteTotal);
				
				if (textValueLength != 0)
				{
					var enclosingContainer:ContainerController = getEnclosingController(startPos);
					if (enclosingContainer)
						ContainerController(enclosingContainer).setTextLength(enclosingContainer.textLength + textValueLength);
				}
			}

			CONFIG::debug { 
				var debugText:String = _blockElement == null ? _text : _blockElement.rawText;
				assert(textLength == (debugText ? debugText.length : 0),"span textLength doesn't match the length of the text property, text property length is " + debugText.length.toString() + " textLength property is " + textLength.toString());
			}
		}
	
		/** @private */
		tlf_internal override function addParaTerminator():void
		{
			CONFIG::debug 
			{ 
				// TODO: Is this assert valid? Do we prevent users from adding para terminators themselves? 
				if (_blockElement && _blockElement.rawText && _blockElement.rawText.length)
					assert(_blockElement.rawText.charAt(_blockElement.rawText.length-1) != SpanElement.kParagraphTerminator,"adding para terminator twice");
			}

			replaceTextInternal(textLength,textLength,SpanElement.kParagraphTerminator);
			
			CONFIG::debug 
			{ 
				// TODO: Is this assert valid? Do we prevent users from adding para terminators themselves? 
				if (_blockElement)
					assert(_blockElement.rawText.charAt(_blockElement.rawText.length-1) == SpanElement.kParagraphTerminator,"adding para terminator failed");
			}			
			
			modelChanged(ModelChange.TEXT_INSERTED,textLength-1,1);
		}
		/** @private */
		tlf_internal override function removeParaTerminator():void
		{
			CONFIG::debug 
			{ 
				var str:String = _blockElement ? _blockElement.rawText : _text;
				assert(str && str.length && str.charAt(str.length-1) == SpanElement.kParagraphTerminator,
					"attempting to remove para terminator when it doesn't exist");
			}
			replaceTextInternal(textLength-1,textLength,"");
			modelChanged(ModelChange.TEXT_DELETED,textLength > 0 ? textLength-1 : 0,1);
		}
		// **************************************** 
		// Begin tree modification support code
		// ****************************************

		/** 
		 * Splits this SpanElement object at the specified position and returns a new SpanElement object for the content
		 * that follows the specified position. 
		 *
		 * <p>This method throws an error if you attempt to split a surrogate pair. In Unicode UTF-16, a surrogate pair is a pair of 
		 * 16-bit code units (a high code unit and a low code unit) that represent one of the abstract Unicode characters 
		 * that cannot be represented in a single 16-bit word. The 16-bit high code unit is in the range of D800 to DBFF. The
		 * 16-bit low code unit is in the range of DC00 to DFFF.</p>
		 * 
		 * @param relativePosition - relative position in the span to create the split
		 * @return - the newly created span. 
		 * @throws RangeError <code>relativePosition</code> is less than 0 or greater than textLength or a surrogate pair is being split.
		 *
		 * @playerversion Flash 10
		 * @playerversion AIR 1.5
	 	 * @langversion 3.0
	 	 * 
	 	 * @private
	 	 */
	 	 
		public override function splitAtPosition(relativePosition:int):FlowElement
		{
			// Note to callers: If you are calling this function outside a try/catch, do ensure that the 
			// state of the model is coherent before the call.
			if (relativePosition < 0 || relativePosition > textLength)
				throw RangeError(GlobalSettings.resourceStringFunction("invalidSplitAtPosition"));
			
			if ((relativePosition < textLength) && CharacterUtil.isLowSurrogate(String(text).charCodeAt(relativePosition)))
				throw RangeError (GlobalSettings.resourceStringFunction("invalidSurrogatePairSplit"));
			
			var newSpan:SpanElement = new SpanElement();
			// clone styling information
			newSpan.id = this.id;
			newSpan.styleName = this.styleName;			
			
			if (parent)
			{
				var newBlockElement:TextElement;
				var newSpanLength:int = textLength - relativePosition;
				if (_blockElement)
				{
				// optimized version leverages player APIs
					// TODO: Jeff to add split on TextElement so we don't have to go find a group every time
					var group:GroupElement = parent.createContentAsGroup();
					
					var elementIndex:int = group.getElementIndex(_blockElement);
					
					CONFIG::debug { assert(elementIndex == parent.getChildIndex(this),"bad group index"); }
					CONFIG::debug { assert(elementIndex != -1 && elementIndex < group.elementCount,"bad span split"); }
					//trace("GROUP BEFORE: " + group.rawText);
					//trace("BLOCK BEFORE: " + group.block.content.rawText);
					//trace("calling group.splitTextElement("+elementIndex.toString()+","+relativePosition.toString()+")");
					group.splitTextElement(elementIndex, relativePosition);
					CONFIG::debug { Debugging.traceFTECall(null,group,"splitTextElement",elementIndex,relativePosition); }

					//trace("GROUP AFTER: " + group.rawText);
					//trace("BLOCK AFTER: " + group.block.content.rawText);
					
					// no guarantee on how the split works
					_blockElement = group.getElementAt(elementIndex);
					CONFIG::debug { Debugging.traceFTECall(_blockElement,group,"getElementAt",elementIndex); }
					newBlockElement = group.getElementAt(elementIndex+1) as TextElement;
					CONFIG::debug { Debugging.traceFTECall(newBlockElement,group,"getElementAt",elementIndex+1); }
				}
				else if (relativePosition < textLength)
				{
					newSpan.text = _text.substr(relativePosition);
					_text = _text.substring(0, relativePosition);
				}

				// Split this span at the offset, into two equivalent spans
				modelChanged(ModelChange.TEXT_DELETED,relativePosition,newSpanLength);
				newSpan.quickInitializeForSplit(this, newSpanLength,newBlockElement);

				setTextLength(relativePosition);
			
				// slices it in, sets the parent and the start
				parent.addChildAfterInternal(this,newSpan);	
				newSpan.modelChanged(ModelChange.ELEMENT_ADDED,0,newSpan.textLength);
			}
			else
			{
				// this version also works if para is non-null but may not be as efficient.
				newSpan.format = format;

				// could be we are splitting 
				if (relativePosition < textLength)
				{
					newSpan.text = String(this.text).substr(relativePosition);
					replaceText(relativePosition,textLength,null);
				}
			}
			
			return newSpan;
		}
		
		/** private */
		tlf_internal override function normalizeRange(normalizeStart:uint,normalizeEnd:uint):void
		{
			if (this.textLength == 1)
			{
				var p:ParagraphElement = getParagraph();
				if (p && p.getLastLeaf() == this)
				{
					var prevLeaf:FlowLeafElement = getPreviousLeaf(p);
					if (prevLeaf)
					{
						this.format = prevLeaf.format;
						this.userStyles = prevLeaf.userStyles ? Property.shallowCopy(prevLeaf.userStyles) : null;
					}
				}
			}
			super.normalizeRange(normalizeStart,normalizeEnd);
		}

		/** @private */
		tlf_internal override function mergeToPreviousIfPossible():Boolean
		{
			// if canReleaseContentElement is false than the contentElement has something special (like an eventMirror) and the span can't be merged
			if (parent && !bindableElement && canReleaseContentElement())
			{
				var myidx:int = parent.getChildIndex(this);
				if (myidx != 0)
				{
					var sib:SpanElement = parent.getChildAt(myidx-1) as SpanElement;
					if (sib != null && sib.canReleaseContentElement() && 
						(equalStylesForMerge(sib) || (this.textLength == 1 && this.hasParagraphTerminator)))
					{
						CONFIG::debug { assert(this.parent == sib.parent, "Should never merge two spans with different parents!"); }
						CONFIG::debug { assert(TextLayoutFormat.isEqual(this.formatForCascade,sib.formatForCascade) || (this.textLength == 1 && this.hasParagraphTerminator), "Bad merge!"); }
						
						// Merge them in the Player's TextBlock structure
						var siblingInsertPosition:int = sib.textLength;
						sib.replaceText(siblingInsertPosition, siblingInsertPosition, this.text);
						parent.replaceChildren(myidx,myidx+1,null);
						return true;
					}
				}
			} 
			return false;
		}
		
		// **************************************** 
		// Begin debug support code
		// ****************************************	
		
		/** @private */
		CONFIG::debug public override function debugCheckFlowElement(depth:int = 0, extraData:String = ""):int
		{
			// debugging function that asserts if the flow element tree is in an invalid state
			
			var rslt:int = super.debugCheckFlowElement(depth,"text:"+String(text).substr(0,32)+" "+extraData);

			var textValue:String = _blockElement ? _blockElement.rawText : _text;
			var textLen:int = textLength;
			if (textValue)
				rslt += assert(textLen == textValue.length,"span is different than its textElement, span text length is " + textValue.length.toString() + " expecting " + textLen.toString());
			else	
				rslt += assert(textLen == 0,"span is different than its textElement, span text length is null expecting " + textLen.toString());
			rslt += assert(this != getParagraph().getLastLeaf() || (textValue.length >= 1 && textValue.substr(textValue.length-1,1) == SpanElement.kParagraphTerminator),"last span in paragraph must end with terminator");
			return rslt;
		}
	}
}