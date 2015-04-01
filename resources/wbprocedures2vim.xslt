<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:transform
     version="1.0"
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>
<xsl:output
  encoding="iso-8859-15"
  method="text"
  omit-xml-declaration="yes"
  doctype-public="-//W3C//DTD HTML 4.01 Transitional//EN"
/>

<xsl:template match="/">
let b:autocomplete_procs = [<xsl:call-template name="procedures-list"/>]
</xsl:template>

<xsl:template name="procedures-list">
    <xsl:for-each select="/wb-export/data/row-data/column-data[@index='0']">'<xsl:value-of select="."/>',</xsl:for-each>
</xsl:template>

</xsl:transform>
