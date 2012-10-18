/*
 * Copyright 2011, Red Hat, Inc. and individual contributors
 * as indicated by the @author tags. See the copyright.txt file in the
 * distribution for a full listing of individual contributors.
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
 */
package org.zanata.client.commands.push;

import java.io.File;
import java.io.IOException;
import java.util.Collections;
import java.util.List;
import java.util.Set;

import org.zanata.client.commands.push.PushCommand.TranslationResourcesVisitor;
import org.zanata.client.config.LocaleMapping;
import org.zanata.rest.StringSet;
import org.zanata.rest.dto.resource.Resource;

/**
 * NB: you must initialise this object with init() after setPushOptions()
 * @author Alex Eng <a href="mailto:aeng@redhat.com">aeng@redhat.com</a>
 *
 **/
public abstract class AbstractPushStrategy extends AbstractCommonPushStrategy<PushOptions>
{
   private StringSet extensions;
   private String fileExtension;

   public abstract Set<String> findDocNames(File srcDir, List<String> includes, List<String> excludes, boolean includeDefaultExclude) throws IOException;

   public abstract Resource loadSrcDoc(File sourceDir, String docName) throws IOException;

   public abstract void visitTranslationResources(String docName, Resource srcDoc, TranslationResourcesVisitor visitor) throws IOException;

   public AbstractPushStrategy(StringSet extensions, String fileExtension)
   {
      this.extensions = extensions;
      this.fileExtension = fileExtension;
   }

   /**
    * Scan srcDir to return a list of all source files.
    * 
    * @param srcDir base directory in which to find source files
    * @param includes empty to find all source files, non-empty to find only the documents in this list
    * @param excludes
    * @param excludeLocaleFileNames adds entries to excludes to ignore any file with a locale id
    *        suffix before the file extension.
    * @param includeDefaultExclude true to also exclude a set of default excludes for common temp file
    *        and source control filenames
    * @return document paths for source files found in srcDir
    */
   public String[] getSrcFiles(File srcDir, List<String> includes, List<String> excludes, boolean excludeLocaleFileNames, boolean includeDefaultExclude)
   {
      if (excludeLocaleFileNames)
      {
         excludeLocaleFileNames(excludes);
      }
      return getSrcFiles(srcDir, includes, excludes, Collections.<String>singletonList(fileExtension), includeDefaultExclude);
   }

   private void excludeLocaleFileNames(List<String> excludes)
   {
      for (LocaleMapping locMap : getOpts().getLocaleMapList())
      {
         String loc = locMap.getJavaLocale().toLowerCase();
         excludes.add("**/*_" + loc + fileExtension);
      }
   }
   
   protected String docNameToFilename(String docName)
   {
      return docName + fileExtension;
   }

   protected String docNameToFilename(String docName, LocaleMapping locale)
   {
      return docName + "_" + locale.getJavaLocale() + fileExtension;
   }

   public StringSet getExtensions()
   {
      return extensions;
   }

   public String getFileExtension()
   {
      return fileExtension;
   }

   public void init()
   {
   }

}


 